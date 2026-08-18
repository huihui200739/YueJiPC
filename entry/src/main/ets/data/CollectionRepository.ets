import relationalStore from '@ohos.data.relationalStore';
import {
  CollectionItem,
  CollectionItemKind,
  CollectionRecord,
  MAX_COLLECTION_DESCRIPTION_LENGTH,
  MAX_COLLECTION_NAME_LENGTH
} from '../model/Models';
import { YueJiDatabase } from './YueJiDatabase';

export class CollectionRepository {
  private database: YueJiDatabase;

  constructor(database: YueJiDatabase) {
    this.database = database;
  }

  async insert(record: CollectionRecord): Promise<void> {
    const name = record.name.trim();
    const description = record.description.trim();
    if (name.length === 0 || name.length > MAX_COLLECTION_NAME_LENGTH ||
      description.length > MAX_COLLECTION_DESCRIPTION_LENGTH) {
      throw new Error('Collection input is invalid');
    }
    await this.ensureUniqueName(name);
    await this.database.getStore().insert('collections', {
      id: record.id,
      name: name,
      description: description,
      created_at: record.createdAt,
      updated_at: record.updatedAt
    });
  }

  async listAll(): Promise<CollectionRecord[]> {
    const predicates = new relationalStore.RdbPredicates('collections');
    predicates.orderByDesc('updated_at');
    const resultSet = await this.database.getStore().query(predicates);
    const records: CollectionRecord[] = [];
    try {
      if (!resultSet.goToFirstRow()) {
        return records;
      }
      do {
        records.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          description: resultSet.getString(resultSet.getColumnIndex('description')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
          updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
        });
      } while (resultSet.goToNextRow());
      return records;
    } finally {
      resultSet.close();
    }
  }

  async update(id: string, name: string, description: string): Promise<number> {
    const normalizedName = name.trim();
    const normalizedDescription = description.trim();
    if (normalizedName.length === 0 || normalizedName.length > MAX_COLLECTION_NAME_LENGTH ||
      normalizedDescription.length > MAX_COLLECTION_DESCRIPTION_LENGTH) {
      throw new Error('Collection input is invalid');
    }
    await this.ensureUniqueName(normalizedName, id);
    const updatedAt = Date.now();
    const values: relationalStore.ValuesBucket = {
      name: normalizedName,
      description: normalizedDescription,
      updated_at: updatedAt
    };
    const predicates = new relationalStore.RdbPredicates('collections');
    predicates.equalTo('id', id);
    const count = await this.database.getStore().update(values, predicates);
    if (count !== 1) {
      throw new Error('Collection was not updated');
    }
    return updatedAt;
  }

  async delete(id: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('collections');
    predicates.equalTo('id', id);
    const count = await this.database.getStore().delete(predicates);
    if (count !== 1) {
      throw new Error('Collection was not deleted');
    }
  }

  async addItem(collectionId: string, itemId: string, itemKind: CollectionItemKind): Promise<void> {
    await this.database.getStore().insert('collection_items', {
      collection_id: collectionId,
      item_id: itemId,
      item_kind: itemKind,
      created_at: Date.now()
    });
  }

  async removeItem(collectionId: string, itemId: string, itemKind: CollectionItemKind): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('collection_items');
    predicates.equalTo('collection_id', collectionId);
    predicates.equalTo('item_id', itemId);
    predicates.equalTo('item_kind', itemKind);
    await this.database.getStore().delete(predicates);
  }

  async listItems(collectionId: string): Promise<CollectionItem[]> {
    const predicates = new relationalStore.RdbPredicates('collection_items');
    predicates.equalTo('collection_id', collectionId);
    predicates.orderByAsc('created_at');
    const resultSet = await this.database.getStore().query(predicates);
    const items: CollectionItem[] = [];
    try {
      if (!resultSet.goToFirstRow()) {
        return items;
      }
      do {
        items.push({
          collectionId: resultSet.getString(resultSet.getColumnIndex('collection_id')),
          itemId: resultSet.getString(resultSet.getColumnIndex('item_id')),
          itemKind: resultSet.getString(resultSet.getColumnIndex('item_kind')) as CollectionItemKind,
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      } while (resultSet.goToNextRow());
      return items;
    } finally {
      resultSet.close();
    }
  }

  async listAllItems(): Promise<CollectionItem[]> {
    const predicates = new relationalStore.RdbPredicates('collection_items');
    predicates.orderByAsc('created_at');
    const resultSet = await this.database.getStore().query(predicates);
    const items: CollectionItem[] = [];
    try {
      if (!resultSet.goToFirstRow()) {
        return items;
      }
      do {
        items.push({
          collectionId: resultSet.getString(resultSet.getColumnIndex('collection_id')),
          itemId: resultSet.getString(resultSet.getColumnIndex('item_id')),
          itemKind: resultSet.getString(resultSet.getColumnIndex('item_kind')) as CollectionItemKind,
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      } while (resultSet.goToNextRow());
      return items;
    } finally {
      resultSet.close();
    }
  }

  async clearAll(): Promise<void> {
    await this.database.getStore().executeSql('DELETE FROM collection_items');
    await this.database.getStore().executeSql('DELETE FROM collections');
  }

  private async ensureUniqueName(name: string, excludedId: string = ''): Promise<void> {
    const normalized = name.trim().toLocaleLowerCase();
    const records = await this.listAll();
    const duplicated = records.some((record: CollectionRecord): boolean =>
      record.id !== excludedId && record.name.trim().toLocaleLowerCase() === normalized);
    if (duplicated) {
      throw new Error('Collection name already exists');
    }
  }
}
