import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { AbilityConstant, Configuration, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ConfigService } from '../services/ConfigService';
import { PollingController } from '../services/PollingController';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[EntryAbility] onCreate');
    AppStorage.setOrCreate('abilityContext', this.context);
    this.syncSystemTheme(this.context?.config?.colorMode);
    void ConfigService.getInstance().loadConfig();
  }

  onDestroy(): void {
    console.info('[EntryAbility] onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[EntryAbility] onWindowStageCreate');
    
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        console.error(`[EntryAbility] Failed to load content. Error: ${JSON.stringify(err)}`);
        return;
      }
      console.info('[EntryAbility] Succeeded in loading content');
    });
  }

  onWindowStageDestroy(): void {
    console.info('[EntryAbility] onWindowStageDestroy');
  }

  onForeground(): void {
    console.info('[EntryAbility] onForeground');
    this.syncSystemTheme(this.context?.config?.colorMode);
  }

  onBackground(): void {
    console.info('[EntryAbility] onBackground');
    PollingController.stopAll();
  }

  onConfigurationUpdate(config: Configuration): void {
    this.syncSystemTheme(config.colorMode);
  }

  private syncSystemTheme(colorMode: ConfigurationConstant.ColorMode | undefined): void {
    AppStorage.setOrCreate(
      'systemColorMode',
      colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    );
  }
}
