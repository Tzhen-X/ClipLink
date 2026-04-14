import { ConfigService } from '../services/ConfigService';
import { AppConfig, ServerConfig } from '../types/ApiTypes';
import { ConfigurationConstant } from '@kit.AbilityKit';

@Component
export default struct SettingsPage {
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State pollingInterval: number = 5;
  @State theme: string = 'auto';
  @State historySize: number = 100;
  @State saveStatus: string = '';
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  private saveStatusTimer: number = -1;

  private configService: ConfigService = ConfigService.getInstance();

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
    this.clearSaveStatusTimer();
  }

  private async initializePage() {
    await this.configService.loadConfig();
    this.loadConfig();
  }

  private loadConfig() {
    const config = this.configService.getConfig();
    this.serverUrl = config.server.url;
    this.username = config.server.username || '';
    this.password = config.server.password || '';
    this.pollingInterval = config.pollingInterval;
    this.theme = config.theme;
    this.historySize = config.maxHistorySize;
  }

  private clearSaveStatusTimer() {
    if (this.saveStatusTimer !== -1) {
      clearTimeout(this.saveStatusTimer);
      this.saveStatusTimer = -1;
    }
  }

  private resetSaveStatusLater() {
    this.clearSaveStatusTimer();
    this.saveStatusTimer = setTimeout(() => {
      this.saveStatus = '';
      this.saveStatusTimer = -1;
    }, 2000);
  }

  private async handleSave() {
    try {
      const config: AppConfig = {
        server: {
          type: 'syncclipboard',
          url: this.serverUrl,
          username: this.username,
          password: this.password
        },
        pollingInterval: this.pollingInterval,
        theme: this.theme as 'light' | 'dark' | 'auto',
        maxHistorySize: this.historySize
      };

      await this.configService.saveConfig(config);
      this.saveStatus = 'Saved successfully';
      this.resetSaveStatusLater();
    } catch (error) {
      console.error('[SettingsPage] handleSave error:', JSON.stringify(error));
      this.saveStatus = 'Save failed';
    }
  }

  build() {
    Scroll() {
      Column() {
        Text('Settings')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDarkTheme() ? '#F5F5F5' : '#222222')
          .margin({ top: 20, bottom: 20 })

        // Server Settings Section
        Column() {
          Text('Server Settings')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 15 })

          Column() {
            Text('Server URL')
              .fontSize(14)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 5 })
            
            TextInput({ text: this.serverUrl })
              .width('100%')
              .onChange((value: string) => {
                this.serverUrl = value;
              })
          }
          .width('100%')
          .margin({ bottom: 15 })

          Column() {
            Text('Username')
              .fontSize(14)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 5 })
            
            TextInput({ text: this.username })
              .width('100%')
              .onChange((value: string) => {
                this.username = value;
              })
          }
          .width('100%')
          .margin({ bottom: 15 })

          Column() {
            Text('Password')
              .fontSize(14)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 5 })
            
            TextInput({ text: this.password })
              .width('100%')
              .type(InputType.Password)
              .onChange((value: string) => {
                this.password = value;
              })
          }
          .width('100%')
          .margin({ bottom: 15 })
        }
        .width('90%')
        .padding(15)
        .backgroundColor(this.isDarkTheme() ? '#1F1F1F' : '#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: 20 })

        // App Settings Section
        Column() {
          Text('App Settings')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 15 })

          Row() {
            Text('Polling Interval (seconds)')
              .fontSize(14)
              .layoutWeight(1)
            
            Counter() {
              Text(this.pollingInterval.toString())
                .fontSize(14)
            }
            .onInc(() => {
              if (this.pollingInterval < 60) {
                this.pollingInterval++;
              }
            })
            .onDec(() => {
              if (this.pollingInterval > 1) {
                this.pollingInterval--;
              }
            })
          }
          .width('100%')
          .margin({ bottom: 15 })

          Row() {
            Text('Theme')
              .fontSize(14)
              .layoutWeight(1)
            
            Select([
              { value: 'Light' },
              { value: 'Dark' },
              { value: 'Auto' }
            ])
              .selected(this.theme === 'light' ? 0 : this.theme === 'dark' ? 1 : 2)
              .value(this.theme === 'light' ? 'Light' : this.theme === 'dark' ? 'Dark' : 'Auto')
              .onSelect((index: number) => {
                this.theme = index === 0 ? 'light' : index === 1 ? 'dark' : 'auto';
              })
          }
          .width('100%')
          .margin({ bottom: 15 })

          Row() {
            Text('Max History Size')
              .fontSize(14)
              .layoutWeight(1)
            
            Counter() {
              Text(this.historySize.toString())
                .fontSize(14)
            }
            .onInc(() => {
              if (this.historySize < 1000) {
                this.historySize += 50;
              }
            })
            .onDec(() => {
              if (this.historySize > 50) {
                this.historySize -= 50;
              }
            })
          }
          .width('100%')
        }
        .width('90%')
        .padding(15)
        .backgroundColor(this.isDarkTheme() ? '#1F1F1F' : '#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: 20 })

        Button('Save')
          .fontSize(16)
          .width(200)
          .onClick(() => this.handleSave())
          .margin({ bottom: 10 })

        if (this.saveStatus) {
          Text(this.saveStatus)
            .fontSize(14)
            .fontColor(this.saveStatus.includes('failed') ? '#FF0000' : '#00AA00')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkTheme() ? '#111111' : '#F5F5F5')
  }
}
