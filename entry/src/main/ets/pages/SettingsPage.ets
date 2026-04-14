import { ConfigService } from '../services/ConfigService';
import { AppConfig, ServerConfig } from '../types/ApiTypes';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';

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

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(this.appTheme, this.systemColorMode);
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

  private async handleThemeSelect(index: number): Promise<void> {
    const selectedTheme = index === 0 ? 'light' : index === 1 ? 'dark' : 'auto';
    this.theme = selectedTheme;
    this.appTheme = selectedTheme;
    await ThemeUtil.applyTheme(selectedTheme, this.systemColorMode);
    try {
      const currentConfig = this.configService.getConfig();
      await this.configService.saveConfig({
        server: currentConfig.server,
        pollingInterval: currentConfig.pollingInterval,
        theme: selectedTheme as 'light' | 'dark' | 'auto',
        maxHistorySize: currentConfig.maxHistorySize
      });
      this.saveStatus = 'Theme updated';
      this.resetSaveStatusLater();
    } catch (error) {
      console.error('[SettingsPage] handleThemeSelect error:', JSON.stringify(error));
      this.saveStatus = 'Theme update failed';
    }
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
      this.appTheme = config.theme;
      await ThemeUtil.applyTheme(config.theme, this.systemColorMode);
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
          .fontColor(this.getPalette().textPrimary)
          .margin({ top: 20, bottom: 20 })

        // Server Settings Section
        Column() {
          Text('Server Settings')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().textPrimary)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 15 })

          Column() {
            Text('Server URL')
              .fontSize(14)
              .fontColor(this.getPalette().textSecondary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 5 })
            
            TextInput({ text: this.serverUrl })
              .width('100%')
              .height(44)
              .backgroundColor(this.getPalette().inputBackground)
              .fontColor(this.getPalette().textPrimary)
              .borderRadius(12)
              .onChange((value: string) => {
                this.serverUrl = value;
              })
          }
          .width('100%')
          .margin({ bottom: 15 })

          Column() {
            Text('Username')
              .fontSize(14)
              .fontColor(this.getPalette().textSecondary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 5 })
            
            TextInput({ text: this.username })
              .width('100%')
              .height(44)
              .backgroundColor(this.getPalette().inputBackground)
              .fontColor(this.getPalette().textPrimary)
              .borderRadius(12)
              .onChange((value: string) => {
                this.username = value;
              })
          }
          .width('100%')
          .margin({ bottom: 15 })

          Column() {
            Text('Password')
              .fontSize(14)
              .fontColor(this.getPalette().textSecondary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 5 })
            
            TextInput({ text: this.password })
              .width('100%')
              .type(InputType.Password)
              .height(44)
              .backgroundColor(this.getPalette().inputBackground)
              .fontColor(this.getPalette().textPrimary)
              .borderRadius(12)
              .onChange((value: string) => {
                this.password = value;
              })
          }
          .width('100%')
          .margin({ bottom: 15 })
        }
        .width('90%')
        .padding(16)
        .backgroundColor(this.getPalette().pageSurface)
        .borderRadius(16)
        .shadow({ radius: 16, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 6 })
        .margin({ bottom: 20 })

        // App Settings Section
        Column() {
          Text('App Settings')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().textPrimary)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 15 })

          Row() {
            Text('Polling Interval (seconds)')
              .fontSize(14)
              .fontColor(this.getPalette().textSecondary)
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
          .padding(12)
          .backgroundColor(this.getPalette().elevatedBackground)
          .borderRadius(12)
          .margin({ bottom: 15 })

          Row() {
            Text('Theme')
              .fontSize(14)
              .fontColor(this.getPalette().textSecondary)
              .layoutWeight(1)
            
            Select([
              { value: 'Light' },
              { value: 'Dark' },
              { value: 'Auto' }
            ])
              .selected(this.theme === 'light' ? 0 : this.theme === 'dark' ? 1 : 2)
              .value(this.theme === 'light' ? 'Light' : this.theme === 'dark' ? 'Dark' : 'Auto')
              .onSelect((index: number) => {
                void this.handleThemeSelect(index);
              })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.getPalette().elevatedBackground)
          .borderRadius(12)
          .margin({ bottom: 15 })

          Row() {
            Text('Max History Size')
              .fontSize(14)
              .fontColor(this.getPalette().textSecondary)
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
          .padding(12)
          .backgroundColor(this.getPalette().elevatedBackground)
          .borderRadius(12)
        }
        .width('90%')
        .padding(16)
        .backgroundColor(this.getPalette().pageSurface)
        .borderRadius(16)
        .shadow({ radius: 16, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 6 })
        .margin({ bottom: 20 })

        Button('Save')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().buttonPrimaryText)
          .width('90%')
          .height(48)
          .backgroundColor(this.getPalette().buttonPrimaryBackground)
          .borderRadius(24)
          .onClick(() => this.handleSave())
          .margin({ bottom: 10 })

        if (this.saveStatus) {
          Text(this.saveStatus)
            .fontSize(14)
            .fontColor(this.saveStatus.includes('failed') ? this.getPalette().danger : this.getPalette().success)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground)
  }
}
