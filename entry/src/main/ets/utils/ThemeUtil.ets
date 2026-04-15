import window from '@ohos.window';
import { ConfigurationConstant } from '@kit.AbilityKit';

export interface ThemePalette {
  isDark: boolean;
  pageBackground: string;
  pageSurface: string;
  cardBackground: string;
  elevatedBackground: string;
  inputBackground: string;
  borderColor: string;
  shadowColor: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accent: string;
  accentSoft: string;
  buttonPrimaryBackground: string;
  buttonPrimaryText: string;
  buttonSecondaryBackground: string;
  buttonSecondaryText: string;
  buttonDangerBackground: string;
  buttonDangerText: string;
  success: string;
  danger: string;
}

export class ThemeUtil {
  static isDarkTheme(appTheme: string, systemColorMode: number): boolean {
    return (
      appTheme === 'dark' ||
      (appTheme === 'auto' &&
        systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
    );
  }

  static getPalette(appTheme: string, systemColorMode: number): ThemePalette {
    const isDark = ThemeUtil.isDarkTheme(appTheme, systemColorMode);
    return isDark
        ? {
          isDark: true,
          pageBackground: '#0B1020',
          pageSurface: '#10182A',
          cardBackground: '#131D31',
          elevatedBackground: '#1A2840',
          inputBackground: '#172338',
          borderColor: '#314563',
          shadowColor: '#00000026',
          textPrimary: '#F5F7FA',
          textSecondary: '#C3CEDD',
          textMuted: '#8C9AAF',
          accent: '#5EA1FF',
          accentSoft: '#233B5F',
          buttonPrimaryBackground: '#5EA1FF',
          buttonPrimaryText: '#08111F',
          buttonSecondaryBackground: '#2A3445',
          buttonSecondaryText: '#E6EDF7',
          buttonDangerBackground: '#A63C4A',
          buttonDangerText: '#FFF5F7',
          success: '#4ECF7A',
          danger: '#FF7D8A'
        }
      : {
          isDark: false,
          pageBackground: '#EEF3FA',
          pageSurface: '#FFFFFF',
          cardBackground: '#FCFDFF',
          elevatedBackground: '#F4F8FF',
          inputBackground: '#FFFFFF',
          borderColor: '#D6E1F0',
          shadowColor: '#17233812',
          textPrimary: '#1B1F27',
          textSecondary: '#5B667A',
          textMuted: '#7F8A9D',
          accent: '#007DFF',
          accentSoft: '#E8F1FF',
          buttonPrimaryBackground: '#007DFF',
          buttonPrimaryText: '#FFFFFF',
          buttonSecondaryBackground: '#EDF2F7',
          buttonSecondaryText: '#243247',
          buttonDangerBackground: '#E64D4F',
          buttonDangerText: '#FFFFFF',
          success: '#00A65A',
          danger: '#D93838'
        };
  }

  static async applyTheme(appTheme: string, systemColorMode: number): Promise<void> {
    const windowStage = AppStorage.get<window.WindowStage>('mainWindowStage');
    if (!windowStage) {
      return;
    }
    const palette = ThemeUtil.getPalette(appTheme, systemColorMode);
    const systemBarContentColor = palette.isDark ? '#FFFFFF' : '#000000';
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowBackgroundColor(palette.pageBackground);
      await mainWindow.setWindowLayoutFullScreen(true);
      await mainWindow.setWindowSystemBarEnable(['status', 'navigation']);
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: systemBarContentColor,
        navigationBarContentColor: systemBarContentColor
      });
    } catch (error) {
      console.error('[ThemeUtil] applyTheme error:', JSON.stringify(error));
    }
  }

  static async applyStoredTheme(): Promise<void> {
    const appTheme = AppStorage.get<string>('appTheme') ?? 'auto';
    const systemColorMode =
      AppStorage.get<number>('systemColorMode') ??
      ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    await ThemeUtil.applyTheme(appTheme, systemColorMode);
  }
}
