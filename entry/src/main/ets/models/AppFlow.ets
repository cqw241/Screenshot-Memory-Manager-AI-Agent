export enum AppPage {
  LOADING = 'LOADING',
  WIZARD = 'WIZARD',
  HOME = 'HOME',
  SETTINGS = 'SETTINGS'
}

export interface StartupRoute {
  page: AppPage;
  recoveryRequired: boolean;
}
