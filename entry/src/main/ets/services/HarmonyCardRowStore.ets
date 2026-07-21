import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { CardStorageError, CardStorageErrorCategory } from '../models/ScreenshotCardModels';
import { CardRow, CardRowStore, CardUnderstandingRowUpdate } from './ScreenshotCardRepository';

const DATABASE_NAME: string = 'shiguang_cards.db';
const DATABASE_VERSION: number = 1;
const TABLE_NAME: string = 'screenshot_cards';

const CREATE_TABLE_SQL: string =
  `CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (` +
  'id TEXT PRIMARY KEY NOT NULL, ' +
  'image_uri TEXT NOT NULL, ' +
  'thumbnail_uri TEXT NOT NULL, ' +
  "type TEXT NOT NULL CHECK (type IN ('POSTER','PICKUP_CODE','DDL_NOTICE','COUPON','UNCATEGORIZED')), " +
  'entities_json TEXT NOT NULL, ' +
  'actions_json TEXT NOT NULL, ' +
  "status TEXT NOT NULL CHECK (status IN ('PARSED','FALLBACK_INVALID_RESPONSE')), " +
  'created_at_ms INTEGER NOT NULL, ' +
  'event_time_ms INTEGER NULL)';

const CREATE_TIMELINE_INDEX_SQL: string =
  `CREATE INDEX IF NOT EXISTS idx_screenshot_cards_timeline ON ${TABLE_NAME} ` +
  '(event_time_ms DESC, created_at_ms DESC, id DESC)';

const SELECT_COLUMNS: string =
  'id, image_uri, thumbnail_uri, type, entities_json, actions_json, status, created_at_ms, event_time_ms';

export class HarmonyCardRowStore implements CardRowStore {
  private readonly context: common.Context;
  private storePromise?: Promise<relationalStore.RdbStore>;

  constructor(context: common.Context) {
    this.context = context;
  }

  async insert(row: CardRow): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await this.getStore();
      const result: number = await store.insert(TABLE_NAME, rowValues(row),
        relationalStore.ConflictResolution.ON_CONFLICT_ABORT);
      if (result < 0) {
        throw new Error('card insert failed');
      }
    } catch (error) {
      throw error as Error;
    }
  }

  async findById(id: string): Promise<CardRow | undefined> {
    let result: relationalStore.ResultSet | undefined;
    try {
      const store: relationalStore.RdbStore = await this.getStore();
      result = await store.querySql(`SELECT ${SELECT_COLUMNS} FROM ${TABLE_NAME} WHERE id = ?`, [id]);
      if (!result.goToFirstRow()) {
        return undefined;
      }
      return readCurrentRow(result);
    } catch (error) {
      throw error as Error;
    } finally {
      closeResult(result);
    }
  }

  async updateUnderstanding(id: string, update: CardUnderstandingRowUpdate): Promise<boolean> {
    try {
      const store: relationalStore.RdbStore = await this.getStore();
      const values: relationalStore.ValuesBucket = {
        type: update.type,
        entities_json: update.entitiesJson,
        actions_json: update.actionsJson,
        status: update.status,
        event_time_ms: update.eventTimeMs
      };
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NAME);
      predicates.equalTo('id', id);
      const affected: number = await store.update(values, predicates);
      if (affected > 0) {
        return true;
      }
      return await this.findById(id) !== undefined;
    } catch (error) {
      throw error as Error;
    }
  }

  async deleteById(id: string): Promise<boolean> {
    try {
      const store: relationalStore.RdbStore = await this.getStore();
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_NAME);
      predicates.equalTo('id', id);
      return await store.delete(predicates) === 1;
    } catch (error) {
      throw error as Error;
    }
  }

  async listTimeline(): Promise<CardRow[]> {
    let result: relationalStore.ResultSet | undefined;
    try {
      const store: relationalStore.RdbStore = await this.getStore();
      result = await store.querySql(`SELECT ${SELECT_COLUMNS} FROM ${TABLE_NAME} ` +
        'ORDER BY event_time_ms DESC, created_at_ms DESC, id DESC');
      const rows: CardRow[] = [];
      if (!result.goToFirstRow()) {
        return rows;
      }
      do {
        rows.push(readCurrentRow(result));
      } while (result.goToNextRow());
      return rows;
    } catch (error) {
      throw error as Error;
    } finally {
      closeResult(result);
    }
  }

  private async getStore(): Promise<relationalStore.RdbStore> {
    if (this.storePromise === undefined) {
      this.storePromise = this.openStore();
    }
    try {
      return await this.storePromise;
    } catch (_error) {
      this.storePromise = undefined;
      throw new CardStorageError(CardStorageErrorCategory.OPEN,
        '本地卡片存储暂时不可用，请稍后重试。');
    }
  }

  private async openStore(): Promise<relationalStore.RdbStore> {
    try {
      const config: relationalStore.StoreConfig = {
        name: DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S3,
        encrypt: true
      };
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(this.context, config);
      if (store.version > DATABASE_VERSION) {
        throw new Error('unsupported card database version');
      }
      if (store.version < DATABASE_VERSION) {
        await initializeVersionOne(store);
      }
      return store;
    } catch (error) {
      throw error as Error;
    }
  }
}

async function initializeVersionOne(store: relationalStore.RdbStore): Promise<void> {
  let transactionStarted: boolean = false;
  try {
    store.beginTransaction();
    transactionStarted = true;
    await store.executeSql(CREATE_TABLE_SQL);
    await store.executeSql(CREATE_TIMELINE_INDEX_SQL);
    store.commit();
    transactionStarted = false;
    store.version = DATABASE_VERSION;
  } catch (error) {
    if (transactionStarted) {
      try {
        store.rollBack();
      } catch (_rollbackError) {
      }
    }
    throw error as Error;
  }
}

function rowValues(row: CardRow): relationalStore.ValuesBucket {
  return {
    id: row.id,
    image_uri: row.imageUri,
    thumbnail_uri: row.thumbnailUri,
    type: row.type,
    entities_json: row.entitiesJson,
    actions_json: row.actionsJson,
    status: row.status,
    created_at_ms: row.createdAtMs,
    event_time_ms: row.eventTimeMs
  };
}

function readCurrentRow(result: relationalStore.ResultSet): CardRow {
  try {
    const eventTimeColumn: number = result.getColumnIndex('event_time_ms');
    return {
      id: result.getString(result.getColumnIndex('id')),
      imageUri: result.getString(result.getColumnIndex('image_uri')),
      thumbnailUri: result.getString(result.getColumnIndex('thumbnail_uri')),
      type: result.getString(result.getColumnIndex('type')),
      entitiesJson: result.getString(result.getColumnIndex('entities_json')),
      actionsJson: result.getString(result.getColumnIndex('actions_json')),
      status: result.getString(result.getColumnIndex('status')),
      createdAtMs: result.getLong(result.getColumnIndex('created_at_ms')),
      eventTimeMs: result.isColumnNull(eventTimeColumn) ? null : result.getLong(eventTimeColumn)
    };
  } catch (error) {
    throw error as Error;
  }
}

function closeResult(result: relationalStore.ResultSet | undefined): void {
  if (result === undefined) {
    return;
  }
  try {
    result.close();
  } catch (_error) {
  }
}
