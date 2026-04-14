import { HistoryRecordDto } from '../types/ApiTypes';
import { HistoryStorageService } from '../services/HistoryStorageService';
import { SyncClipboardService } from '../services/SyncClipboardService';
import { ConfigService } from '../services/ConfigService';
import { ClipboardUtil } from '../utils/ClipboardUtil';
import { ConfigurationConstant } from '@kit.AbilityKit';

@Component
export default struct HistoryPage {
  @State historyList: HistoryRecordDto[] = [];
  @State isLoading: boolean = false;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

  private storageService: HistoryStorageService = HistoryStorageService.getInstance();

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
      this.historyList = localRecords;

      // Sync from server
      const syncService = this.createSyncService();
      const serverRecords = await syncService.queryHistoryPages(config.maxHistorySize);

      for (const record of serverRecords) {
        await this.storageService.upsertRecord(record);
      }

      this.historyList = await this.storageService.queryRecords(config.maxHistorySize);
    } catch (error) {
      console.error('[HistoryPage] loadHistory error:', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  private async handleItemClick(item: HistoryRecordDto) {
    try {
      if (item.type === 'Text') {
        const text = item.hasData
          ? await this.createSyncService().downloadHistoryText(`Text-${item.hash}`)
          : (item.text || '');
        await ClipboardUtil.setClipboardText(text);
        console.info('[HistoryPage] Copied to clipboard');
      }
    } catch (error) {
      console.error('[HistoryPage] handleItemClick error:', JSON.stringify(error));
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
          .fontColor(this.isDarkTheme() ? '#F5F5F5' : '#222222')
          .margin({ top: 20, bottom: 20 })

      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
      } else if (this.historyList.length === 0) {
        Text('No history items')
          .fontSize(16)
          .fontColor(this.isDarkTheme() ? '#BBBBBB' : '#999999')
          .margin({ top: 50 })
      } else {
        List({ space: 10 }) {
          ForEach(this.historyList, (item: HistoryRecordDto) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.type)
                    .fontSize(12)
                    .fontColor(this.isDarkTheme() ? '#CFCFCF' : '#666666')
                    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                    .backgroundColor(this.isDarkTheme() ? '#333333' : '#E0E0E0')
                    .borderRadius(4)
                  
                  Text(this.formatDate(item.lastAccessed))
                    .fontSize(12)
                    .fontColor(this.isDarkTheme() ? '#BBBBBB' : '#999999')
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

                Text(item.text || '[No preview]')
                  .fontSize(14)
                  .fontColor(this.isDarkTheme() ? '#F5F5F5' : '#222222')
                  .width('100%')
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .maxLines(2)

                if (item.size) {
                  Text(`${item.size} bytes`)
                    .fontSize(12)
                    .fontColor(this.isDarkTheme() ? '#BBBBBB' : '#999999')
                    .margin({ top: 5 })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.isDarkTheme() ? '#1F1F1F' : '#FFFFFF')
              .borderRadius(8)
              .shadow({ radius: 2, color: '#00000010' })
            }
            .onClick(() => this.handleItemClick(item))
          }, (item: HistoryRecordDto) => `${item.type}-${item.hash}`)
        }
        .width('90%')
        .layoutWeight(1)
      }

      Button('Refresh')
        .fontSize(16)
        .width(150)
        .margin({ top: 20, bottom: 20 })
        .onClick(() => this.loadHistory())
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isDarkTheme() ? '#111111' : '#F5F5F5')
  }
}
