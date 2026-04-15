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

@Component
export default struct HistoryPage {
  @State historyList: HistoryViewItem[] = [];
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @StorageLink('historyRefreshToken') @Watch('handleHistoryRefreshTokenChange')
  historyRefreshToken: number = 0;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('preferPureBlackInDark') preferPureBlackInDark: boolean = false;
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

  private storageService: HistoryStorageService = HistoryStorageService.getInstance();
  private readonly listStyle = getHistoryListStyleSpec();

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
    void this.loadHistory();
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
    await this.loadHistory();
  }

  private async loadHistory() {
    if (!this.isRefreshing) {
      this.isLoading = true;
    }
    try {
      const config = ConfigService.getInstance().getConfig();
      // Load from local storage first
      const localRecords = await this.storageService.queryRecords(config.maxHistorySize);
      this.setHistoryRecords(localRecords);
      void this.loadImagePreviews();

      // Sync from server
      const syncService = this.createSyncService();
      const serverRecords = await syncService.queryHistoryPages(config.maxHistorySize);

      for (const record of serverRecords) {
        await this.storageService.upsertRecord(record);
      }

      this.setHistoryRecords(await this.storageService.queryRecords(config.maxHistorySize));
      void this.loadImagePreviews();
    } catch (error) {
      console.error('[HistoryPage] loadHistory error:', JSON.stringify(error));
    } finally {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  private setHistoryRecords(records: HistoryRecordDto[]): void {
    const existing = new Map<string, image.PixelMap>();
    this.historyList.forEach((item: HistoryViewItem): void => {
      if (item.previewPixelMap) {
        existing.set(`${item.type}-${item.hash}`, item.previewPixelMap);
      }
    });
    this.historyList = records.map((record: HistoryRecordDto) =>
      this.createHistoryViewItem(record, existing.get(`${record.type}-${record.hash}`))
    );
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

  private async loadImagePreviews(): Promise<void> {
    const syncService = this.createSyncService();
    for (const item of this.historyList) {
      if (item.type !== 'Image' || !item.hasData || item.previewPixelMap) {
        continue;
      }
      try {
        const buffer = await syncService.downloadHistoryBinary(`${item.type}-${item.hash}`);
        const pixelMap = await ImageUtil.createPixelMapFromBuffer(buffer);
        const nextItems: HistoryViewItem[] = [];
        this.historyList.forEach((current: HistoryViewItem): void => {
          if (current.type === item.type && current.hash === item.hash) {
            nextItems.push(this.createHistoryViewItem(current, pixelMap));
          } else {
            nextItems.push(this.createHistoryViewItem(current, current.previewPixelMap));
          }
        });
        this.historyList = nextItems;
      } catch (error) {
        console.error('[HistoryPage] loadImagePreviews error:', JSON.stringify(error));
      }
    }
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
          }
          .width('96%')
          .layoutWeight(1)
        }
        .width('96%')
        .layoutWeight(1)
        .onRefreshing(() => {
          this.isRefreshing = true;
          void this.loadHistory();
        })
      }

    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.getPalette().pageBackground)
  }
}
