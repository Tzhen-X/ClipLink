import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { AbilityConstant, Configuration, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ConfigService } from '../services/ConfigService';
import { PollingController } from '../services/PollingController';
import { ThemeUtil } from '../utils/ThemeUtil';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onCreate');
    AppStorage.setOrCreate('abilityContext', this.context);
    AppStorage.setOrCreate('historyRefreshToken', 0);
    this.syncSystemTheme(this.context?.config?.colorMode);
    void ConfigService.getInstance()
      .loadConfig()
      .then(() => ThemeUtil.applyStoredTheme())
      .catch((error: Error | Object | string) => {
        console.error('[EntryAbility] loadConfig error:', JSON.stringify(error));
      });
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageCreate');
    AppStorage.setOrCreate('mainWindowStage', windowStage);
    
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        console.error(`[EntryAbility] Failed to load content. Error: ${JSON.stringify(err)}`);
        return;
      }
      void ThemeUtil.applyStoredTheme();
      console.info('[EntryAbility] Succeeded in loading content');
    });
  }

  onWindowStageDestroy(): void {
    console.info('[EntryAbility] onWindowStageDestroy');
  }

  onForeground(): void {
    console.info('[EntryAbility] onForeground');
    this.syncSystemTheme(this.context?.config?.colorMode);
    void ThemeUtil.applyStoredTheme();
  }

  onBackground(): void {
    console.info('[EntryAbility] onBackground');
    PollingController.stopAll();
  }

  onConfigurationUpdate(config: Configuration): void {
    this.syncSystemTheme(config.colorMode);
    void ThemeUtil.applyStoredTheme();
  }

  private syncSystemTheme(colorMode: ConfigurationConstant.ColorMode | undefined): void {
    AppStorage.setOrCreate(
      'systemColorMode',
      colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    );
  }
}
