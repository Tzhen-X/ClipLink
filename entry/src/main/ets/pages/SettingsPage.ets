import { ConfigService } from '../services/ConfigService';
import { AppConfig, ServerConfig } from '../types/ApiTypes';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';
import { getActionButtonSpec, getSettingsSectionSpecs } from '../utils/PageScaffoldUtil';

@Component
export default struct SettingsPage {
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State pollingInterval: number = 5;
  @State theme: string = 'auto';
  @State preferPureBlackInDark: boolean = false;
  @State historySize: number = 100;
  @State saveStatus: string = '';
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('preferPureBlackInDark') storedPureBlackPreference: boolean = false;
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  private saveStatusTimer: number = -1;
  private readonly sectionSpecs = getSettingsSectionSpecs();

  private configService: ConfigService = ConfigService.getInstance();

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(
      this.appTheme as 'light' | 'dark' | 'auto',
      this.systemColorMode,
      this.preferPureBlackInDark
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
    this.preferPureBlackInDark = config.preferPureBlackInDark;
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
    await ThemeUtil.applyTheme(
      selectedTheme as 'light' | 'dark' | 'auto',
      this.systemColorMode,
      this.preferPureBlackInDark
    );
    try {
      const currentConfig = this.configService.getConfig();
      await this.configService.saveConfig({
        server: currentConfig.server,
        pollingInterval: currentConfig.pollingInterval,
        theme: selectedTheme as 'light' | 'dark' | 'auto',
        preferPureBlackInDark: this.preferPureBlackInDark,
        maxHistorySize: currentConfig.maxHistorySize
      });
      this.storedPureBlackPreference = this.preferPureBlackInDark;
      this.saveStatus = 'Theme updated';
      this.resetSaveStatusLater();
    } catch (error) {
      console.error('[SettingsPage] handleThemeSelect error:', JSON.stringify(error));
      this.saveStatus = 'Theme update failed';
    }
  }

  private async handlePureBlackToggle(isOn: boolean): Promise<void> {
    this.preferPureBlackInDark = isOn;
    this.storedPureBlackPreference = isOn;
    await ThemeUtil.applyTheme(
      this.theme as 'light' | 'dark' | 'auto',
      this.systemColorMode,
      isOn
    );
    try {
      const currentConfig = this.configService.getConfig();
      await this.configService.saveConfig({
        server: currentConfig.server,
        pollingInterval: currentConfig.pollingInterval,
        theme: this.theme as 'light' | 'dark' | 'auto',
        preferPureBlackInDark: isOn,
        maxHistorySize: currentConfig.maxHistorySize
      });
      this.saveStatus = isOn ? 'Pure black enabled' : 'Pure black disabled';
      this.resetSaveStatusLater();
    } catch (error) {
      console.error('[SettingsPage] handlePureBlackToggle error:', JSON.stringify(error));
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
        preferPureBlackInDark: this.preferPureBlackInDark,
        maxHistorySize: this.historySize
      };

      await this.configService.saveConfig(config);
      this.appTheme = config.theme;
      this.storedPureBlackPreference = config.preferPureBlackInDark;
      await ThemeUtil.applyTheme(config.theme, this.systemColorMode, config.preferPureBlackInDark);
      this.saveStatus = 'Saved successfully';
      this.resetSaveStatusLater();
    } catch (error) {
      console.error('[SettingsPage] handleSave error:', JSON.stringify(error));
      this.saveStatus = 'Save failed';
    }
  }

  @Builder
  private Stepper(value: number, onDec: () => void, onInc: () => void) {
    Row({ space: 8 }) {
      Button('-', {
        type: ButtonType.Capsule,
        buttonStyle: ButtonStyleMode.NORMAL,
        controlSize: ControlSize.SMALL
      })
        .fontColor(this.getPalette().buttonSecondaryText)
        .backgroundColor(this.getPalette().buttonSecondaryBackground)
        .onClick(onDec)

      Text(value.toString())
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getPalette().textPrimary)
        .width(36)
        .textAlign(TextAlign.Center)

      Button('+', {
        type: ButtonType.Capsule,
        buttonStyle: ButtonStyleMode.NORMAL,
        controlSize: ControlSize.SMALL
      })
        .fontColor(this.getPalette().buttonSecondaryText)
        .backgroundColor(this.getPalette().buttonSecondaryBackground)
        .onClick(onInc)
    }
    .padding({
      left: $r('sys.float.padding_level2'),
      right: $r('sys.float.padding_level2'),
      top: $r('sys.float.padding_level2'),
      bottom: $r('sys.float.padding_level2')
    })
    .backgroundColor(this.getPalette().elevatedBackground)
    .borderRadius($r('sys.float.corner_radius_level8'))
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('Settings')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPalette().textPrimary)
          Text('Connection details stay separate from everyday app preferences.')
            .fontSize($r('sys.float.Body_S'))
            .fontColor(this.getPalette().textSecondary)
        }
        .width('90%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: $r('sys.float.padding_level8') })

        Column({ space: 14 }) {
          Text(this.sectionSpecs[0].title)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().textPrimary)
          Text(this.sectionSpecs[0].description)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(this.getPalette().textSecondary)

          Column({ space: 12 }) {
            Column({ space: 6 }) {
              Text('Server URL')
                .fontSize($r('sys.float.Body_M'))
                .fontColor(this.getPalette().textSecondary)
                .alignSelf(ItemAlign.Start)
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

            Column({ space: 6 }) {
              Text('Username')
                .fontSize($r('sys.float.Body_M'))
                .fontColor(this.getPalette().textSecondary)
                .alignSelf(ItemAlign.Start)
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

            Column({ space: 6 }) {
              Text('Password')
                .fontSize($r('sys.float.Body_M'))
                .fontColor(this.getPalette().textSecondary)
                .alignSelf(ItemAlign.Start)
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
          }
          .width('100%')

          Button('Save Connection', {
            type: ButtonType.Capsule,
            buttonStyle: ButtonStyleMode.NORMAL,
            controlSize: getActionButtonSpec('settings-save').controlSize === 'small'
              ? ControlSize.SMALL
              : ControlSize.NORMAL
          })
            .alignSelf(ItemAlign.End)
            .fontColor(this.getPalette().buttonPrimaryText)
            .backgroundColor(this.getPalette().buttonPrimaryBackground)
            .onClick(() => this.handleSave())
        }
        .width('90%')
        .padding(16)
        .backgroundColor(this.getPalette().pageSurface)
        .borderRadius($r('sys.float.corner_radius_level8'))
        .shadow({ radius: 16, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 6 })

        Column({ space: 14 }) {
          Text(this.sectionSpecs[1].title)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().textPrimary)
          Text(this.sectionSpecs[1].description)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(this.getPalette().textSecondary)

          Column() {
            Row() {
              Column({ space: 2 }) {
                Text('Polling Interval')
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getPalette().textPrimary)
                Text('How often the app pulls from the server when auto sync is enabled.')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor(this.getPalette().textSecondary)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              this.Stepper(
                this.pollingInterval,
                () => {
                  if (this.pollingInterval > 1) {
                    this.pollingInterval--;
                  }
                },
                () => {
                  if (this.pollingInterval < 60) {
                    this.pollingInterval++;
                  }
                }
              )
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })

            Divider()
              .strokeWidth(1)
              .color(this.getPalette().borderColor)

            Row() {
              Column({ space: 2 }) {
                Text('Theme')
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getPalette().textPrimary)
                Text('Applies immediately, including dark mode.')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor(this.getPalette().textSecondary)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

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
            .padding({ top: 12, bottom: 12 })

            Divider()
              .strokeWidth(1)
              .color(this.getPalette().borderColor)

            Row() {
              Column({ space: 2 }) {
                Text('Use Pure Black in Dark')
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getPalette().textPrimary)
                Text('Affects Dark mode directly, and Auto mode whenever the system switches to dark.')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor(this.getPalette().textSecondary)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.preferPureBlackInDark })
                .onChange((isOn: boolean) => {
                  void this.handlePureBlackToggle(isOn);
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })

            Divider()
              .strokeWidth(1)
              .color(this.getPalette().borderColor)

            Row() {
              Column({ space: 2 }) {
                Text('Max History Size')
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getPalette().textPrimary)
                Text('Controls how many recent items stay available locally.')
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor(this.getPalette().textSecondary)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              this.Stepper(
                this.historySize,
                () => {
                  if (this.historySize > 50) {
                    this.historySize -= 50;
                  }
                },
                () => {
                  if (this.historySize < 1000) {
                    this.historySize += 50;
                  }
                }
              )
            }
            .width('100%')
            .padding({ top: 12, bottom: 6 })
          }
          .width('100%')
        }
        .width('90%')
        .padding(16)
        .backgroundColor(this.getPalette().pageSurface)
        .borderRadius($r('sys.float.corner_radius_level8'))
        .shadow({ radius: 16, color: this.getPalette().shadowColor, offsetX: 0, offsetY: 6 })

        if (this.saveStatus) {
          Text(this.saveStatus)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(this.saveStatus.includes('failed') ? this.getPalette().danger : this.getPalette().success)
            .margin({ bottom: 10 })
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
