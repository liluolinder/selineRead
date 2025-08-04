/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */


import { RelationalStoreDataBaseTableType } from "../enums/RelationalStoreDataBaseTableType";
import { I_RelationalStoreDataBaseTableForm } from "../interfaces/I_LDataBaseManager";

export let zlibHaveDownloadTable:I_RelationalStoreDataBaseTableForm[] = [
  {
    key:'ID',
    isKey:true,
    needAutoIncrement:true,
    type:RelationalStoreDataBaseTableType.INTEGER,
    canNull:false
  },
  {
    key:'BookID',
    isKey:false,
    needAutoIncrement:false,
    type:RelationalStoreDataBaseTableType.INTEGER,
    canNull:true
  },
  {
    key:'BookHref',
    isKey:false,
    needAutoIncrement:false,
    type:RelationalStoreDataBaseTableType.TEXT,
    canNull:true
  },
  {
    key:'BookName',
    isKey:false,
    needAutoIncrement:false,
    type:RelationalStoreDataBaseTableType.TEXT,
    canNull:true
  },
  {
    key:'BookAuthor',
    isKey:false,
    needAutoIncrement:false,
    type:RelationalStoreDataBaseTableType.TEXT,
    canNull:true
  },
  {
    key:'BookPublisher',
    isKey:false,
    needAutoIncrement:false,
    type:RelationalStoreDataBaseTableType.TEXT,
    canNull:true
  },
  {
    key:'BookImage',
    isKey:false,
    needAutoIncrement:false,
    type:RelationalStoreDataBaseTableType.TEXT,
    canNull:true
  },
  {
    key:'BookDownLoadTime',
    isKey:false,
    needAutoIncrement:false,
    type:RelationalStoreDataBaseTableType.TEXT,
    canNull:true
  },
]
