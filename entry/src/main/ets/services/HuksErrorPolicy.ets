const HUKS_ERROR_ENTITY_NOT_EXIST: number = 12000011;

export function isMissingHuksEntity(errorCode: number): boolean {
  return errorCode === HUKS_ERROR_ENTITY_NOT_EXIST;
}
