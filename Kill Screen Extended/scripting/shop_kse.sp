#include <sourcemod>
#include <shop>
#include <kse>
#include <devcolors>

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

public Plugin myinfo = 
{
	name = "[Shop]Kill Screen Extended",
	author = "JDW",
	version = "1.0",
	url = "devengine.tech"
};

int price,
    sellPrice,
    duration;

ItemId id;


public void OnPluginStart()
{
    LoadTranslations("kse_shop.phrases");
    LoadTranslations("kse.phrases");

    char buffer[128];

    ConVar cvar;

	FormatEx(buffer, sizeof(buffer), "%t", "PRICE");
    (cvar = CreateConVar("kse_shop_price", "700", buffer)).AddChangeHook(CVarPrice);
    price = cvar.IntValue;

	FormatEx(buffer, sizeof(buffer), "%t", "SELL_PRICE");
    (cvar = CreateConVar("kse_shop_sell_price", "650", buffer)).AddChangeHook(CVarSellPrice);
    sellPrice = cvar.IntValue;

	FormatEx(buffer, sizeof(buffer), "%t", "DURATION");
    (cvar = CreateConVar("kse_shop_duration", "86400", buffer)).AddChangeHook(CVarDuration);
    duration = cvar.IntValue;

    AutoExecConfig(true, "kse_shop", "shop");

    if(Shop_IsStarted())
    {
        Shop_Started();
    }
}

public void OnPluginEnd()
{
    Shop_UnregisterMe();
}

public void OnConfigsExecuted()
{
    if(!PrivateModCheck())
    {
        SetFailState("kse_private_mode variable must be true (1)");
    }
}

public void Shop_Started()
{
    CategoryId category = Shop_RegisterCategory("effects", "", "", OnDisplayCallback);

    if(category == INVALID_CATEGORY)
    {
        SetFailState("Failed to register category");
    }

    if(Shop_StartItem(category, "kse"))
    {
        Shop_SetInfo("", "", price, sellPrice, Item_None, duration);
        Shop_SetCallbacks(OnItemRegistered, _, _, OnItemDisplayCallback, OnItemDescriptionCallback, _, OnItemBuyCallback);
        Shop_EndItem();
    }
    else 
    {
        SetFailState("Failed to register item");
    }
}

public void CVarPrice(ConVar cvar, const char[] oldValue, const char[] newValue)
{ 
    price = cvar.IntValue;
}

public void CVarSellPrice(ConVar cvar, const char[] oldValue, const char[] newValue)
{ 
    sellPrice = cvar.IntValue;
}

public void CVarDuration(ConVar cvar, const char[] oldValue, const char[] newValue)
{ 
    duration = cvar.IntValue;
}

public bool OnDisplayCallback(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen)
{
    FormatEx(buffer, maxlen, "%T", "CATEGORY", client);

    return true;
}

public int OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	id = item_id;
}

public bool OnItemDisplayCallback(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
    FormatEx(buffer, maxlen, "%T", "ITEM_NAME", client);

    return true;
}

public bool OnItemDescriptionCallback(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, const char[] description, char[] buffer, int maxlen)
{
    FormatEx(buffer, maxlen, "%T", "DESCRIPTION", client);

    return true;
}

public bool OnItemBuyCallback(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int _price, int sell_price, int value)
{
    KSE_GrantAccess(client);

    return true;
}

public void Shop_OnAuthorized(int client)
{
    CreateTimer(3.0, CheckItemInInventory, GetClientUserId(client));
}

public Action CheckItemInInventory(Handle timer, int userId)
{
    static int client;
    client = GetClientOfUserId(userId);

    if(client && Shop_IsClientHasItem(client, id))
    {
        KSE_GrantAccess(client);
        DCPrintToChat(client, "%T%T", "PREFIX", client, "WELCOME", client);
    }
    
    return Plugin_Stop;
}