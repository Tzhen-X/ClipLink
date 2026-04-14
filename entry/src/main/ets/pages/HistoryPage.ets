import { HistoryRecordDto } from '../types/ApiTypes';
import { HistoryStorageService } from '../services/HistoryStorageService';
import { SyncClipboardService } from '../services/SyncClipboardService';
import { ConfigService } from '../services/ConfigService';
import { ClipboardUtil } from '../utils/ClipboardUtil';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ImageUtil } from '../utils/ImageUtil';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';

interface HistoryViewItem extends HistoryRecordDto {
  previewPixelMap?: image.PixelMap;
}

@Component
export default struct HistoryPage {
  @State historyList: HistoryViewItem[] = [];
  @State isLoading: boolean = false;
  @State actionStatus: string = '';
  @StorageLink('historyRefreshToken') @Watch('handleHistoryRefreshTokenChange')
  historyRefreshToken: number = 0;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

  private storageService: HistoryStorageService = HistoryStorageService.getInstance();

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(this.appTheme, this.systemColorMode);
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
    this.isLoading = true;
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
        this.actionStatus = 'Text copied to clipboard';
        return;
      }

      if (item.type === 'Image' && item.hasData) {
        const binary = await this.createSyncService().downloadHistoryBinary(`Image-${item.hash}`);
        const pixelMap = item.previewPixelMap ?? await ImageUtil.createPixelMapFromBuffer(binary);
        await ClipboardUtil.setClipboardImage(pixelMap);
        this.actionStatus = 'Image copied to clipboard';
        if (!item.previewPixelMap) {
          void pixelMap.release();
        }
      }
    } catch (error) {
      console.error('[HistoryPage] handleItemClick error:', JSON.stringify(error));
      this.actionStatus = 'Copy failed';
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
      this.actionStatus = `Saved to ${filePath}`;
    } catch (error) {
      console.error('[HistoryPage] handleImageDownload error:', JSON.stringify(error));
      this.actionStatus = 'Image download failed';
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
        Text('History')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getPalette().textPrimary)
          .margin({ top: 20, bottom: 20 })

      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
      } else if (this.historyList.length === 0) {
        Text('No history items')
          .fontSize(16)
          .fontColor(this.getPalette().textMuted)
          .margin({ top: 50 })
      } else {
        List({ space: 10 }) {
          ForEach(this.historyList, (item: HistoryViewItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.type)
                    .fontSize(12)
                    .fontColor(this.getPalette().textSecondary)
                    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                    .backgroundColor(this.getPalette().elevatedBackground)
                    .borderRadius(4)
                  
                  Text(this.formatDate(item.lastAccessed))
                    .fontSize(12)
                    .fontColor(this.getPalette().textMuted)
                    .margin({ left: 10 })
                  
                  Blank()

                  if (item.starred) {
                    Text('★')
                      .fontSize(16)
                      .fontColor('#FFD700')
                  }
                }
                .width('100%')
                .margin({ bottom: 5 })

                if (item.type === 'Image') {
                  if (item.previewPixelMap) {
                    Image(item.previewPixelMap)
                      .width('100%')
                      .height(150)
                      .objectFit(ImageFit.Contain)
                      .borderRadius(8)
                      .backgroundColor(this.getPalette().elevatedBackground)
                  } else {
                    Text(item.hasData ? '[Image loading...]' : '[Image preview unavailable]')
                      .fontSize(14)
                      .fontColor(this.getPalette().textSecondary)
                      .width('100%')
                      .padding(12)
                      .backgroundColor(this.getPalette().elevatedBackground)
                      .borderRadius(8)
                  }
                } else {
                  Text(item.text || '[No preview]')
                    .fontSize(14)
                    .fontColor(this.getPalette().textPrimary)
                    .width('100%')
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .maxLines(2)
                }

                if (item.size) {
                  Text(`${item.size} bytes`)
                    .fontSize(12)
                    .fontColor(this.getPalette().textMuted)
                    .margin({ top: 5 })
                }

                if (item.type === 'Image' && item.hasData) {
                  Row() {
                    Button('Download')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getPalette().buttonSecondaryText)
                      .backgroundColor(this.getPalette().buttonSecondaryBackground)
                      .borderRadius(18)
                      .onClick(() => this.handleImageDownload(item))
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                  .margin({ top: 10 })
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.getPalette().pageSurface)
              .borderRadius(16)
              .shadow({ radius: 16, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 6 })
            }
            .onClick(() => this.handleItemClick(item))
          }, (item: HistoryRecordDto) => `${item.type}-${item.hash}`)
        }
        .width('90%')
        .layoutWeight(1)
      }

      if (this.actionStatus) {
        Text(this.actionStatus)
          .fontSize(13)
          .fontColor(this.actionStatus.includes('failed') ? this.getPalette().danger : this.getPalette().success)
          .margin({ top: 12 })
      }

      Button('Refresh')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getPalette().buttonSecondaryText)
        .width('90%')
        .height(48)
        .backgroundColor(this.getPalette().buttonSecondaryBackground)
        .borderRadius(24)
        .margin({ top: 20, bottom: 20 })
        .onClick(() => this.loadHistory())
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.getPalette().pageBackground)
  }
}
