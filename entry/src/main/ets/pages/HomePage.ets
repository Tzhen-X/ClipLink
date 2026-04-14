import { ClipboardUtil } from '../utils/ClipboardUtil';
import { SyncClipboardService } from '../services/SyncClipboardService';
import { ConfigService } from '../services/ConfigService';
import { PollingController } from '../services/PollingController';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';
import { HistoryStorageService } from '../services/HistoryStorageService';
import { HistoryRecordDto } from '../types/ApiTypes';
import { image } from '@kit.ImageKit';
import { ImageUtil } from '../utils/ImageUtil';

interface HomeHistoryPreviewItem extends HistoryRecordDto {
  previewPixelMap?: image.PixelMap;
}

@Component
export default struct HomePage {
  @State currentText: string = '';
  @State syncStatus: string = 'Idle';
  @State isPolling: boolean = false;
  @State latestHistoryItem?: HomeHistoryPreviewItem = undefined;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  @StorageLink('isPollingEnabled') isPollingEnabled: boolean = false;
  @StorageLink('historyRefreshToken') @Watch('handleHistoryRefreshTokenChange')
  historyRefreshToken: number = 0;
  private pollingController: PollingController = new PollingController();
  private historyStorageService: HistoryStorageService = HistoryStorageService.getInstance();
  private syncStatusTimer: number = -1;
  private initToken: number = 0;
  private readonly clipboardUpdateHandler = (): void => {
    void this.loadCurrentClipboard();
  };

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(this.appTheme, this.systemColorMode);
  }

  aboutToAppear() {
    ClipboardUtil.onUpdate(this.clipboardUpdateHandler);
    void this.initializePage();
  }

  aboutToDisappear() {
    this.initToken++;
    ClipboardUtil.offUpdate(this.clipboardUpdateHandler);
    this.clearSyncStatusTimer();
    this.pollingController.dispose();
    void this.latestHistoryItem?.previewPixelMap?.release();
  }

  private clearSyncStatusTimer(): void {
    if (this.syncStatusTimer !== -1) {
      clearTimeout(this.syncStatusTimer);
      this.syncStatusTimer = -1;
    }
  }

  private resetSyncStatusLater(): void {
    this.clearSyncStatusTimer();
    this.syncStatusTimer = setTimeout((): void => {
      this.syncStatus = 'Idle';
      this.syncStatusTimer = -1;
    }, 2000);
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
    const currentToken = ++this.initToken;
    await ConfigService.getInstance().loadConfig();
    if (currentToken !== this.initToken) {
      return;
    }
    await this.loadCurrentClipboard();
    await this.loadLatestHistory();
    if (currentToken !== this.initToken) {
      return;
    }
    this.isPolling = this.isPollingEnabled;
    if (this.isPollingEnabled) {
      const config = ConfigService.getInstance().getConfig();
      if (currentToken !== this.initToken) {
        return;
      }
      this.pollingController.start(config.pollingInterval, async () => {
        await this.handleDownload();
      });
    }
  }

  private async loadCurrentClipboard() {
    try {
      this.currentText = await ClipboardUtil.getClipboardSummary();
    } catch (error) {
      console.error('[HomePage] loadCurrentClipboard error:', JSON.stringify(error));
      this.currentText = 'Error reading clipboard';
    }
  }

  private async handleUpload() {
    this.syncStatus = 'Uploading...';
    try {
      const syncService = this.createSyncService();
      const text = await ClipboardUtil.getClipboardText();
      if (!text) {
        const summary = await ClipboardUtil.getClipboardSummary();
        throw new Error(summary === 'Empty clipboard' ? 'Clipboard is empty' : 'Current clipboard is not plain text');
      }
      await syncService.uploadTextContent(text);
      await this.syncLatestHistoryFromServer();
      this.syncStatus = 'Upload Success';
      this.currentText = text;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[HomePage] handleUpload error:', JSON.stringify(error));
      this.syncStatus = `Upload Error: ${message || 'Unknown'}`;
    }

    this.resetSyncStatusLater();
  }

  private async handleDownload() {
    this.syncStatus = 'Downloading...';
    try {
      const syncService = this.createSyncService();
      const text = await syncService.downloadTextContent();
      await ClipboardUtil.setClipboardText(text);
      await this.syncLatestHistoryFromServer();
      this.currentText = text || 'Empty clipboard';
      this.syncStatus = 'Download Success';
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error('[HomePage] handleDownload error:', JSON.stringify(error));
      this.syncStatus = `Download Error: ${message || 'Unknown'}`;
    }

    this.resetSyncStatusLater();
  }

  private togglePolling() {
    if (this.isPolling) {
      this.pollingController.stop();
      this.isPolling = false;
      this.isPollingEnabled = false;
    } else {
      const config = ConfigService.getInstance().getConfig();
      this.pollingController.start(config.pollingInterval, async () => {
        await this.handleDownload();
      });
      this.isPolling = true;
      this.isPollingEnabled = true;
    }
  }

  private handleHistoryRefreshTokenChange(): void {
    void this.loadLatestHistory();
  }

  private async syncLatestHistoryFromServer(): Promise<void> {
    try {
      const records = await this.createSyncService().queryHistoryPages(1);
      if (records.length > 0) {
        await this.historyStorageService.upsertRecord(records[0]);
      }
    } catch (error) {
      console.error('[HomePage] syncLatestHistoryFromServer error:', JSON.stringify(error));
    } finally {
      this.historyRefreshToken += 1;
    }
  }

  private async loadLatestHistory(): Promise<void> {
    try {
      const records = await this.historyStorageService.queryRecords(1);
      const nextRecord = records.length > 0 ? records[0] : undefined;
      const previousPixelMap = this.latestHistoryItem?.previewPixelMap;
      if (!nextRecord) {
        if (previousPixelMap) {
          void previousPixelMap.release();
        }
        this.latestHistoryItem = undefined;
        return;
      }

      const nextItem: HomeHistoryPreviewItem = {
        hash: nextRecord.hash,
        type: nextRecord.type,
        text: nextRecord.text,
        createTime: nextRecord.createTime,
        lastModified: nextRecord.lastModified,
        lastAccessed: nextRecord.lastAccessed,
        starred: nextRecord.starred,
        pinned: nextRecord.pinned,
        size: nextRecord.size,
        hasData: nextRecord.hasData,
        version: nextRecord.version,
        isDeleted: nextRecord.isDeleted
      };

      if (
        previousPixelMap &&
        this.latestHistoryItem &&
        this.latestHistoryItem.type === nextItem.type &&
        this.latestHistoryItem.hash === nextItem.hash
      ) {
        nextItem.previewPixelMap = previousPixelMap;
      } else if (previousPixelMap) {
        void previousPixelMap.release();
      }

      if (nextItem.type === 'Image' && nextItem.hasData && !nextItem.previewPixelMap) {
        const buffer = await this.createSyncService().downloadHistoryBinary(`Image-${nextItem.hash}`);
        nextItem.previewPixelMap = await ImageUtil.createPixelMapFromBuffer(buffer);
      }

      this.latestHistoryItem = nextItem;
    } catch (error) {
      console.error('[HomePage] loadLatestHistory error:', JSON.stringify(error));
    }
  }

  build() {
    Column() {
      Text('Home')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ top: 20, bottom: 20 })

      Column() {
        Text('Current Clipboard')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().textSecondary)
          .margin({ bottom: 10 })
        
        Text(this.currentText)
          .fontSize(14)
          .fontColor(this.getPalette().textPrimary)
          .width('100%')
          .height(150)
          .padding(10)
          .backgroundColor(this.getPalette().elevatedBackground)
          .borderRadius(8)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(6)
      }
      .width('90%')
      .margin({ bottom: 20 })
      .padding(16)
      .backgroundColor(this.getPalette().cardBackground)
      .borderRadius(16)
      .shadow({ radius: 12, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 4 })

      if (this.latestHistoryItem) {
        Column() {
          Row() {
            Text('Latest History')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getPalette().textSecondary)
            Blank()
            Text(this.latestHistoryItem.type)
              .fontSize(12)
              .fontColor(this.getPalette().accent)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(this.getPalette().accentSoft)
              .borderRadius(12)
          }
          .width('100%')
          .margin({ bottom: 10 })

          if (this.latestHistoryItem.type === 'Image' && this.latestHistoryItem.previewPixelMap) {
            Image(this.latestHistoryItem.previewPixelMap)
              .width('100%')
              .height(140)
              .objectFit(ImageFit.Contain)
              .borderRadius(12)
              .backgroundColor(this.getPalette().elevatedBackground)
          } else {
            Text(this.latestHistoryItem.text || '[No preview]')
              .fontSize(14)
              .fontColor(this.getPalette().textPrimary)
              .width('100%')
              .padding(12)
              .backgroundColor(this.getPalette().elevatedBackground)
              .borderRadius(12)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          if (this.latestHistoryItem.size) {
            Text(`${this.latestHistoryItem.size} bytes`)
              .fontSize(12)
              .fontColor(this.getPalette().textMuted)
              .margin({ top: 8 })
          }
        }
        .width('90%')
        .padding(16)
        .margin({ bottom: 20 })
        .backgroundColor(this.getPalette().cardBackground)
        .borderRadius(16)
        .shadow({ radius: 12, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 4 })
      }

      Row({ space: 12 }) {
        Button('Upload')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().buttonPrimaryText)
          .width('42%')
          .height(44)
          .backgroundColor(this.getPalette().buttonPrimaryBackground)
          .borderRadius(22)
          .onClick(() => this.handleUpload())
        
        Button('Download')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().buttonSecondaryText)
          .width('42%')
          .height(44)
          .backgroundColor(this.getPalette().buttonSecondaryBackground)
          .borderRadius(22)
          .onClick(() => this.handleDownload())
      }
      .width('90%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 20 })

      Button(this.isPolling ? 'Stop Auto-Sync' : 'Start Auto-Sync')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isPolling ? this.getPalette().buttonDangerText : this.getPalette().buttonPrimaryText)
        .width('90%')
        .height(48)
        .backgroundColor(this.isPolling ? this.getPalette().buttonDangerBackground : this.getPalette().buttonPrimaryBackground)
        .borderRadius(24)
        .onClick(() => this.togglePolling())
        .margin({ bottom: 20 })

      Column() {
        Text('Sync Status')
          .fontSize(14)
          .fontColor(this.getPalette().textSecondary)
          .margin({ bottom: 5 })
        
        Text(this.syncStatus)
          .fontSize(16)
          .fontColor(this.syncStatus.includes('Error') ? this.getPalette().danger :
                     this.syncStatus.includes('Success') ? this.getPalette().success : this.getPalette().textSecondary)
      }
      .width('90%')
      .padding(16)
      .backgroundColor(this.getPalette().cardBackground)
      .borderRadius(16)
      .shadow({ radius: 12, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 4 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.getPalette().pageBackground)
  }
}
