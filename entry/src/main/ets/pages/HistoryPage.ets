import { HistoryRecordDto } from '../types/ApiTypes';
import { HistoryStorageService } from '../services/HistoryStorageService';
import { SyncClipboardService } from '../services/SyncClipboardService';
import { ConfigService } from '../services/ConfigService';
import { ClipboardUtil } from '../utils/ClipboardUtil';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ImageUtil } from '../utils/ImageUtil';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';
import { getHistoryActionFeedback, getHistoryListStyleSpec } from '../utils/PageScaffoldUtil';

interface HistoryViewItem extends HistoryRecordDto {
  previewPixelMap?: image.PixelMap;
}

const PAGE_SIZE = 30;
const PREVIEW_CONCURRENCY = 3;

@Component
export default struct HistoryPage {
  @State historyList: HistoryViewItem[] = [];
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @StorageLink('historyRefreshToken') @Watch('handleHistoryRefreshTokenChange')
  historyRefreshToken: number = 0;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('preferPureBlackInDark') preferPureBlackInDark: boolean = false;
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

  private storageService: HistoryStorageService = HistoryStorageService.getInstance();
  private readonly listStyle = getHistoryListStyleSpec();
  private currentPage: number = 1;
  private loadSeq: number = 0;

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(
      this.appTheme as 'light' | 'dark' | 'auto',
      this.systemColorMode,
      this.preferPureBlackInDark
    );
  }

  private showActionToast(message: string, duration: number = 1600): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: duration
    });
  }

  aboutToAppear() {
    void this.initializePage();
  }

  aboutToDisappear() {
    this.releasePreviewImages();
  }

  private handleHistoryRefreshTokenChange(): void {
    void this.refresh();
  }

  private createSyncService(): SyncClipboardService {
    const config = ConfigService.getInstance().getConfig();
    return new SyncClipboardService(
      config.server.url,
      config.server.username,
      config.server.password
    );
  }

  private async initializePage() {
    await ConfigService.getInstance().loadConfig();
    await this.refresh();
  }

  private async refresh(): Promise<void> {
    if (this.isLoadingMore) {
      return;
    }
    const seq = ++this.loadSeq;
    if (!this.isRefreshing) {
      this.isLoading = true;
    }
    this.currentPage = 1;
    this.hasMore = true;

    try {
      const syncService = this.createSyncService();

      // 1. Local first for instant UI
      const localRecords = await this.storageService.queryRecords(PAGE_SIZE, 0);
      if (seq !== this.loadSeq) return;
      this.setHistoryRecords(localRecords, false);
      void this.loadImagePreviews(syncService, seq);

      // 2. Server first page
      const serverRecords = await syncService.queryHistoryPage(1);
      if (seq !== this.loadSeq) return;

      for (const record of serverRecords) {
        await this.storageService.upsertRecord(record);
      }
      if (seq !== this.loadSeq) return;

      const merged = await this.storageService.queryRecords(PAGE_SIZE, 0);
      if (seq !== this.loadSeq) return;
      this.setHistoryRecords(merged, false);
      this.hasMore = serverRecords.length >= PAGE_SIZE || merged.length >= PAGE_SIZE;
      void this.loadImagePreviews(syncService, seq);
    } catch (error) {
      console.error('[HistoryPage] refresh error:', JSON.stringify(error));
    } finally {
      if (seq === this.loadSeq) {
        this.isLoading = false;
        this.isRefreshing = false;
      }
    }
  }

  private async loadMore(): Promise<void> {
    if (this.isLoadingMore || this.isRefreshing || !this.hasMore) {
      return;
    }
    this.isLoadingMore = true;
    const seq = this.loadSeq;
    const nextPage = this.currentPage + 1;

    try {
      const syncService = this.createSyncService();
      const serverRecords = await syncService.queryHistoryPage(nextPage);
      if (seq !== this.loadSeq) return;

      if (serverRecords.length > 0) {
        for (const record of serverRecords) {
          await this.storageService.upsertRecord(record);
        }
      }
      if (seq !== this.loadSeq) return;

      const localPage = await this.storageService.queryRecords(
        PAGE_SIZE,
        this.historyList.length
      );
      if (seq !== this.loadSeq) return;

      if (localPage.length === 0 && serverRecords.length === 0) {
        this.hasMore = false;
      } else {
        this.appendHistoryRecords(localPage);
        this.currentPage = nextPage;
        if (serverRecords.length < PAGE_SIZE && localPage.length < PAGE_SIZE) {
          this.hasMore = false;
        }
        void this.loadImagePreviews(syncService, seq);
      }
    } catch (error) {
      console.error('[HistoryPage] loadMore error:', JSON.stringify(error));
    } finally {
      if (seq === this.loadSeq) {
        this.isLoadingMore = false;
      }
    }
  }

  private setHistoryRecords(records: HistoryRecordDto[], append: boolean): void {
    const existing = new Map<string, image.PixelMap>();
    const keepKeys = new Set<string>();
    records.forEach((r: HistoryRecordDto): void => {
      keepKeys.add(`${r.type}-${r.hash}`);
    });

    this.historyList.forEach((item: HistoryViewItem): void => {
      const key = `${item.type}-${item.hash}`;
      if (item.previewPixelMap) {
        if (keepKeys.has(key) || append) {
          existing.set(key, item.previewPixelMap);
        } else {
          void item.previewPixelMap.release();
        }
      }
    });

    const mapped: HistoryViewItem[] = records.map((record: HistoryRecordDto) =>
      this.createHistoryViewItem(record, existing.get(`${record.type}-${record.hash}`))
    );

    if (append) {
      const seen = new Set<string>();
      this.historyList.forEach((item: HistoryViewItem): void => {
        seen.add(`${item.type}-${item.hash}`);
      });
      const appended: HistoryViewItem[] = [];
      mapped.forEach((item: HistoryViewItem): void => {
        const key = `${item.type}-${item.hash}`;
        if (!seen.has(key)) {
          seen.add(key);
          appended.push(item);
        }
      });
      if (appended.length > 0) {
        this.historyList = this.historyList.concat(appended);
      }
    } else {
      this.historyList = mapped;
    }
  }

  private appendHistoryRecords(records: HistoryRecordDto[]): void {
    this.setHistoryRecords(records, true);
  }

  private createHistoryViewItem(
    record: HistoryRecordDto,
    previewPixelMap?: image.PixelMap
  ): HistoryViewItem {
    return {
      hash: record.hash,
      type: record.type,
      text: record.text,
      createTime: record.createTime,
      lastModified: record.lastModified,
      lastAccessed: record.lastAccessed,
      starred: record.starred,
      pinned: record.pinned,
      size: record.size,
      hasData: record.hasData,
      version: record.version,
      isDeleted: record.isDeleted,
      previewPixelMap: previewPixelMap
    };
  }

  private async loadImagePreviews(syncService: SyncClipboardService, seq: number): Promise<void> {
    const pending: HistoryViewItem[] = this.historyList.filter((item: HistoryViewItem): boolean =>
      item.type === 'Image' && !!item.hasData && !item.previewPixelMap
    );
    if (pending.length === 0) return;

    let cursor = 0;
    const worker = async (): Promise<void> => {
      while (cursor < pending.length) {
        if (seq !== this.loadSeq) return;
        const item = pending[cursor++];
        try {
          const buffer = await syncService.downloadHistoryBinary(`${item.type}-${item.hash}`);
          if (seq !== this.loadSeq) return;
          const pixelMap = await ImageUtil.createPixelMapFromBuffer(buffer);
          if (seq !== this.loadSeq) {
            void pixelMap.release();
            return;
          }
          this.applyPreview(item.type, item.hash, pixelMap);
        } catch (error) {
          console.error('[HistoryPage] loadImagePreviews error:', JSON.stringify(error));
        }
      }
    };

    const workerCount = Math.min(PREVIEW_CONCURRENCY, pending.length);
    const workers: Promise<void>[] = [];
    for (let i = 0; i < workerCount; i++) {
      workers.push(worker());
    }
    await Promise.all(workers);
  }

  private applyPreview(type: string, hash: string, pixelMap: image.PixelMap): void {
    const idx = this.historyList.findIndex((i: HistoryViewItem): boolean =>
      i.type === type && i.hash === hash
    );
    if (idx < 0) {
      void pixelMap.release();
      return;
    }
    const current = this.historyList[idx];
    if (current.previewPixelMap) {
      void pixelMap.release();
      return;
    }
    const next: HistoryViewItem[] = this.historyList.slice();
    next[idx] = this.createHistoryViewItem(current, pixelMap);
    this.historyList = next;
  }

  private releasePreviewImages(): void {
    this.historyList.forEach((item: HistoryViewItem): void => {
      void item.previewPixelMap?.release();
    });
  }

  private async handleItemClick(item: HistoryViewItem) {
    try {
      if (item.type === 'Text') {
        const text = item.hasData
          ? await this.createSyncService().downloadHistoryText(`Text-${item.hash}`)
          : (item.text || '');
        await ClipboardUtil.setClipboardText(text);
        const feedback = getHistoryActionFeedback('copy-text', true);
        this.showActionToast(feedback.message, feedback.duration);
        return;
      }

      if (item.type === 'Image' && item.hasData) {
        const binary = await this.createSyncService().downloadHistoryBinary(`Image-${item.hash}`);
        const pixelMap = item.previewPixelMap ?? await ImageUtil.createPixelMapFromBuffer(binary);
        await ClipboardUtil.setClipboardImage(pixelMap);
        const feedback = getHistoryActionFeedback('copy-image', true);
        this.showActionToast(feedback.message, feedback.duration);
        if (!item.previewPixelMap) {
          void pixelMap.release();
        }
      }
    } catch (error) {
      console.error('[HistoryPage] handleItemClick error:', JSON.stringify(error));
      const feedback = getHistoryActionFeedback('copy-text', false);
      this.showActionToast(feedback.message, feedback.duration);
    }
  }

  private async handleImageDownload(item: HistoryViewItem): Promise<void> {
    try {
      const binary = await this.createSyncService().downloadHistoryBinary(`${item.type}-${item.hash}`);
      const filePath = await ImageUtil.saveBufferToDownloadFile(
        binary,
        `${item.type}-${item.hash}`,
        ImageUtil.guessImageExtension(binary)
      );
      const feedback = getHistoryActionFeedback('save-image', true);
      this.showActionToast(`${feedback.message}: ${filePath}`, feedback.duration);
    } catch (error) {
      console.error('[HistoryPage] handleImageDownload error:', JSON.stringify(error));
      const feedback = getHistoryActionFeedback('save-image', false);
      this.showActionToast(feedback.message, feedback.duration);
    }
  }

  private formatDate(dateStr?: string): string {
    if (!dateStr) {
      return '';
    }
    try {
      const date = new Date(dateStr);
      return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`;
    } catch (error) {
      return dateStr;
    }
  }

  @Builder
  private FooterBuilder() {
    if (this.isLoadingMore) {
      Row() {
        LoadingProgress().width(24).height(24)
        Text('Loading more...')
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.getPalette().textSecondary)
          .margin({ left: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 12, bottom: 12 })
    } else if (!this.hasMore && this.historyList.length > 0) {
      Text('No more items')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor(this.getPalette().textSecondary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 })
    }
  }

  build() {
    Column() {
      Column() {
        Text('History')
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getPalette().textPrimary)
      }
      .width('90%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: $r('sys.float.padding_level8'), bottom: $r('sys.float.padding_level6') })

      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
      } else if (this.historyList.length === 0) {
        Text('No history items')
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.getPalette().textSecondary)
          .margin({ top: 50 })
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ space: 10 }) {
            ForEach(this.historyList, (item: HistoryViewItem) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(item.type)
                      .fontSize($r('sys.float.Body_S'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getPalette().textPrimary)

                    Blank()

                    if (item.starred) {
                      Text('★')
                        .fontSize($r('sys.float.Body_L'))
                        .fontColor('#FFD700')
                    }

                    Text(this.formatDate(item.lastAccessed))
                      .fontSize($r('sys.float.Caption_M'))
                      .fontColor(this.getPalette().textSecondary)
                  }
                  .width('100%')

                  if (item.type === 'Image') {
                    if (item.previewPixelMap) {
                      Image(item.previewPixelMap)
                        .width('100%')
                        .height(this.listStyle.previewHeight)
                        .objectFit(ImageFit.Contain)
                        .borderRadius($r('sys.float.corner_radius_level6'))
                        .backgroundColor(this.getPalette().elevatedBackground)
                    } else {
                      Text(item.hasData ? '[Image loading...]' : '[Image preview unavailable]')
                        .fontSize($r('sys.float.Body_M'))
                        .fontColor(this.getPalette().textSecondary)
                        .width('100%')
                        .padding($r('sys.float.padding_level4'))
                        .backgroundColor(this.getPalette().elevatedBackground)
                        .borderRadius($r('sys.float.corner_radius_level6'))
                    }
                  } else {
                      Text(item.text || '[No preview]')
                        .fontSize($r('sys.float.Body_M'))
                        .fontColor(this.getPalette().textPrimary)
                        .width('100%')
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .maxLines(3)
                  }

                  Row() {
                    Text(item.size ? `${item.size} bytes` : ' ')
                      .fontSize($r('sys.float.Caption_M'))
                      .fontColor(this.getPalette().textSecondary)
                    Blank()

                    if (item.type === 'Image' && item.hasData) {
                      Button('Save', {
                        type: ButtonType.Capsule,
                        buttonStyle: ButtonStyleMode.NORMAL,
                        controlSize: ControlSize.SMALL
                      })
                        .fontColor(this.getPalette().buttonSecondaryText)
                        .backgroundColor(this.getPalette().buttonSecondaryBackground)
                        .onClick(() => this.handleImageDownload(item))
                    }
                  }
                  .width('100%')
                }
                .width('100%')
                .padding($r('sys.float.padding_level5'))
                .backgroundColor(this.getPalette().pageSurface)
                .borderRadius($r('sys.float.corner_radius_level8'))
                .shadow({ radius: 6, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 2 })
              }
              .onClick(() => this.handleItemClick(item))
            }, (item: HistoryRecordDto) => `${item.type}-${item.hash}`)

            ListItem() {
              this.FooterBuilder()
            }
          }
          .width('96%')
          .layoutWeight(1)
          .onReachEnd(() => {
            void this.loadMore();
          })
        }
        .width('96%')
        .layoutWeight(1)
        .onRefreshing(() => {
          void this.refresh();
        })
      }

    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.getPalette().pageBackground)
  }
}
