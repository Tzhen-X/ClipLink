import { ClipboardUtil } from '../utils/ClipboardUtil';
import { SyncClipboardService } from '../services/SyncClipboardService';
import { ConfigService } from '../services/ConfigService';
import { PollingController } from '../services/PollingController';
import { ConfigurationConstant } from '@kit.AbilityKit';

@Component
export default struct HomePage {
  @State currentText: string = '';
  @State syncStatus: string = 'Idle';
  @State isPolling: boolean = false;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  @StorageLink('isPollingEnabled') isPollingEnabled: boolean = false;
  private pollingController: PollingController = new PollingController();
  private syncStatusTimer: number = -1;
  private initToken: number = 0;

  private isDarkTheme(): boolean {
    return (
      this.appTheme === 'dark' ||
      (this.appTheme === 'auto' &&
        this.systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
    );
  }

  aboutToAppear() {
    void this.initializePage();
  }

  aboutToDisappear() {
    this.initToken++;
    this.clearSyncStatusTimer();
    this.pollingController.dispose();
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
      const text = await ClipboardUtil.getClipboardText();
      this.currentText = text || 'Empty clipboard';
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
      await syncService.uploadTextContent(text);
      this.syncStatus = 'Upload Success';
      this.currentText = text || 'Empty clipboard';
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

  build() {
    Column() {
      Text('Home')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })

      Column() {
        Text('Current Clipboard')
          .fontSize(16)
          .margin({ bottom: 10 })
        
        Text(this.currentText)
          .fontSize(14)
          .fontColor(this.isDarkTheme() ? '#F5F5F5' : '#222222')
          .width('100%')
          .height(150)
          .padding(10)
          .backgroundColor(this.isDarkTheme() ? '#2A2A2A' : '#F0F0F0')
          .borderRadius(8)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(6)
      }
      .width('90%')
      .margin({ bottom: 20 })

      Row() {
        Button('Upload')
          .fontSize(16)
          .width(100)
          .onClick(() => this.handleUpload())
        
        Button('Download')
          .fontSize(16)
          .width(100)
          .margin({ left: 20 })
          .onClick(() => this.handleDownload())
      }
      .margin({ bottom: 20 })

      Button(this.isPolling ? 'Stop Auto-Sync' : 'Start Auto-Sync')
        .fontSize(16)
        .width(200)
        .onClick(() => this.togglePolling())
        .margin({ bottom: 20 })

      Column() {
        Text('Sync Status')
          .fontSize(14)
          .margin({ bottom: 5 })
        
        Text(this.syncStatus)
          .fontSize(16)
          .fontColor(this.syncStatus.includes('Error') ? '#FF0000' : 
                     this.syncStatus.includes('Success') ? '#00AA00' : this.isDarkTheme() ? '#CFCFCF' : '#666666')
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isDarkTheme() ? '#111111' : '#F5F5F5')
  }
}
