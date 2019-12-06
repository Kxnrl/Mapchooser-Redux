/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          shop.inc                                       */
/*  Description:   A new Shop system for source game.             */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2017/02/01 11:37:14                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/


#if defined _Shop_Include_
    #endinput
#endif

#define _Shop_Include_

#define MAJORV "0"
#define MINORV "1"
#define BUILDs "<commit-count>"

typedef MenuDetailFunc = function void (int client, const char[] uniqueId, bool inventory);
typedef BuyItemFunc = function void (int client, int cost, const char[] uniqueId);
typedef SellItemFunc = function void (int client, int earn, const char[] uniqueId);

native  int MG_Shop_RegItemCategory(const char[] category, bool Equipable, MenuDetailFunc inventoryMenu);
native  int MG_Shop_RemoveItemCategory(const char[] category);
native  int MG_Shop_GetItemIndex(const char[] uniqueId);
native bool MG_Shop_GetItemFullName(const char[] uniqueId);

native bool MG_Shop_HasClientItem(int client, const char[] uniqueId);
native  int MG_Shop_ClientGetDateofExpiration(int client, const char[] uniqueId);
native  int MG_Shop_ClientGetDateofPurchase(int client, const char[] uniqueId);
native  int MG_Shop_ClientGetCostofPurchase(int client, const char[] uniqueId);
native  int MG_Shop_GetClientMoney(int client);
native bool MG_Shop_ClientEarnMoney(int client, int earn, const char[] reason = "reason unknown");
native bool MG_Shop_ClientCostMoney(int client, int cost, const char[] reason = "reason unknown");
native void MG_Shop_ClientBuyItem(int client, int cost, const char[] uniqueId, BuyItemFunc buyFunc);
native void MG_Shop_ClientSellItem(int client, const char[] uniqueId, SellItemFunc sellFunc);
native void MG_Shop_BuyItemMenu(int client, const char[] uniqueId);
native void MG_Shop_DisplayItemMenu(int client, const char[] uniqueId);
native void MG_Shop_DisplayPreviousMenu(int client);

public SharedPlugin __pl_shop_core =
{
	name = "shop-core",
	file = "shop-core.smx",
#if !defined REQUIRE_PLUGIN
    required = 0
#else
    required = 1
#endif
};