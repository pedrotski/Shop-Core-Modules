#include <shop>
#include <sourcemod>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = 
{
	name		= "SpeedMeter",
	author 		= "iLoco",
	description = "Простой спидометр в худе",
	version 	= "1.0.0",
	url 		= "http://www.hlmod.ru"
};

Handle gHud;

Handle iTimer[MAXPLAYERS+1];
bool iTabEnable[MAXPLAYERS+1];
int iEnable[MAXPLAYERS+1];

ConVar cvar_Color, cvar_Pos, cvar_Update, cvar_Price, cvar_SellPrice, cvar_Duration;
float cwPos[2], cwUpdateTime;
int cwColor[4];

ItemId gItemId;

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnPluginStart()
{
	gHud = CreateHudSynchronizer();

	(cvar_Color = CreateConVar("sm_shop_speedmeter_color", "0 255 0 100", "RGBA Hud Color")).AddChangeHook(ConVar_OnChanged);
	ExplodeValue(cvar_Color, cwColor);

	(cvar_Pos = CreateConVar("sm_shop_speedmeter_position", "0.65 0.95", "Speedometer position in HUD. X/Y")).AddChangeHook(ConVar_OnChanged);
	ExplodeValue(cvar_Pos, cwPos);

	(cvar_Update = CreateConVar("sm_shop_speedmeter_update_time", "0.1", "HUD update rate, in seconds")).AddChangeHook(ConVar_OnChanged);
	cwUpdateTime = cvar_Update.FloatValue;

	(cvar_Price = CreateConVar("sm_shop_speedmeter_price", "500", "Purchase price")).AddChangeHook(ConVar_OnChanged);
	(cvar_SellPrice = CreateConVar("sm_shop_speedmeter_sellprice", "250", "Sell Price)).AddChangeHook(ConVar_OnChanged);
	(cvar_Duration = CreateConVar("sm_shop_speedmeter_duration", "0", "Duration")).AddChangeHook(ConVar_OnChanged);
	
	AutoExecConfig(true, "speedmeter", "shop");
	LoadTranslations("shop_speed_meter.phrases");

	if(Shop_IsStarted())	
		Shop_Started();
}

public void ConVar_OnChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(cvar == cvar_Color)
		ExplodeValue(cvar_Color, cwColor);
	else if(cvar == cvar_Pos)
		ExplodeValue(cvar_Pos, cwPos);
	else if(cvar == cvar_Update)
	{
		cwUpdateTime = cvar.FloatValue;

		for(int i = 1; i <= MaxClients; i++)	if(IsClientAuthorized(i) && IsClientInGame(i) && iTimer[i])
		{
			delete iTimer[i];
			iTimer[i] = CreateTimer(cwUpdateTime, Timer_Display, GetClientOfUserId(i), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else if(cvar_Price)
		Shop_SetItemPrice(gItemId, cvar.IntValue);
	else if(cvar_SellPrice)
		Shop_SetItemSellPrice(gItemId, cvar.IntValue);
	else if(cvar_Duration)
		Shop_SetItemValue(gItemId, cvar.IntValue);
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory("ability", "Abilities", "");

	if(Shop_StartItem(category_id, "speedmeter"))
	{
		Shop_SetInfo("speedmeter", "", cvar_Price.IntValue, cvar_SellPrice.IntValue, Item_Togglable, cvar_Duration.IntValue);
		Shop_SetCallbacks(CallBack_Shop_OnItemRegistered, CallBack_Shop_OnItemUsed, _, CallBack_Shop_OnDisplay);
		Shop_EndItem();
	}
}

public bool CallBack_Shop_OnDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "Menu. SpeedMeter", client);
	return true;
}

public ShopAction CallBack_Shop_OnItemUsed(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	iEnable[client] = !isOn;

	if (isOn || elapsed)
		return Shop_UseOff;

	return Shop_UseOn;
}

public void CallBack_Shop_OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	gItemId = item_id;
}

stock void ExplodeValue(ConVar cvar, any[] value)
{
	char buff[32], exp[4][4];

	cvar.GetString(buff, sizeof(buff));
	int count = ExplodeString(buff, " ", exp, 4, 4);

	for(int i; i < count; i++) 
	{
		if(count > 2)
			value[i] = StringToInt(exp[i]);
		else
			value[i] = StringToFloat(exp[i]);
	}
}

public Action Timer_Display(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	
	if(!IsClientInGame(client) || !iEnable[client])
	{
		iTimer[client] = null;
		return Plugin_Stop;
	}
	
	if(!iTabEnable[client])
	{
		SetHudTextParams(cwPos[0], cwPos[1], 0.5, cwColor[0], cwColor[1], cwColor[2], cwColor[3], 0, 0.0, 0.1, 0.1);
		ShowSyncHudText(client, gHud, "%T", "Hud. Speed", client, GetClientSpeed(client));
	}
	
	return Plugin_Continue;
}

stock int GetClientSpeed(int client)
{
	float vec[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec);
	
	return RoundToNearest(SquareRoot(vec[0] * vec[0] + vec[1] * vec[1]) * GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue"));
}

public void OnPlayerRunCmdPost(int client, int buttons)
{
	static int _buttons[MAXPLAYERS+1];
	
	if(buttons & IN_SCORE && _buttons[client] & IN_SCORE)
			iTabEnable[client] = true;
	
	else if(_buttons[client] & IN_SCORE)
		iTabEnable[client] = false;

	_buttons[client] = buttons;
}
