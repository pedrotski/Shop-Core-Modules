#include <csgo_colors>
#include <shop>
#include <sdktools>

#if SOURCEMOD_V_MINOR < 10 
---> #error This plugin only compile on SM 1.10
#endif

int PriceTurret, SellPriceTurret, RoundUse;
int RoundUsed[MAXPLAYERS+1];

ItemId idTurret;

public Plugin myinfo ={
	name = "[Shop] DroneGun (DZ)",
    	description = "Turrets from danger zone",
	author = "-=HellFire=-",
	version = "1.3",
	url = "VK: vk.com/insellx | HLMOD: hlmod.ru/members/hellfire.105029"
};

public void OnPluginStart()
{
	HookEvent("round_start", RoundStart, EventHookMode_PostNoCopy);
	RegConsoleCmd("sm_turret", TurretCMD);
	
	ConVar hCvar;

	HookConVarChange((hCvar = CreateConVar("sm_shop_turret_price", "10000", "Turret purchase price.")), TurretPrice);
	PriceTurret = hCvar.IntValue;

	HookConVarChange((hCvar = CreateConVar("sm_shop_turret_sellprice", "5000", "Turret Sell Price.")), TurretSellPrice);
	SellPriceTurret = hCvar.IntValue;

	HookConVarChange((hCvar = CreateConVar("sm_shop_turret_per_round", "3", "Max. number of turrets in a round")), RoundUseTurret);
	RoundUse = hCvar.IntValue;

	AutoExecConfig(true, "shop_turret", "shop");

	CloseHandle(hCvar);

    if(Shop_IsStarted()) Shop_Started();

    if(GetEngineVersion() != Engine_CSGO){
        SetFailState("This plugin only for CS:GO");
    }
}

public void OnPluginEnd()
{
    Shop_UnregisterMe();
}

public void Shop_Started()
{
    CategoryId CATEGORY = Shop_RegisterCategory("Turret", "Turret", "");

    if(CATEGORY == INVALID_CATEGORY)
    {
        SetFailState("Failed to register category");
    }

    if(Shop_StartItem(CATEGORY, "turret"))
    {
		Shop_SetInfo("Turret", "Install a turret from the Danger Zone", PriceTurret, SellPriceTurret, Item_Finite);
		Shop_SetCallbacks(OnItemRegistered, OnTurretUse);
		Shop_EndItem();
    	}
    	else 
    	{
        SetFailState("Failed to register item");
    	}
}

public OnItemRegistered(CategoryId category_id, const char [] CATEGORY, const char[] item, ItemId item_id)
{
	idTurret = item_id;
}

public int TurretPrice(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
    PriceTurret = hCvar.IntValue;
}

public int TurretSellPrice(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
    SellPriceTurret = hCvar.IntValue;
}

public int RoundUseTurret(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
	RoundUse = hCvar.IntValue;
}

public ShopAction OnTurretUse(int client, CategoryId category_id, const char[] CATEGORY, ItemId item_id, const char[] item)
{
		if (RoundUse > 0 && RoundUsed[client] >= RoundUse)
		{
			CGOPrintToChat(client, "{GREEN}[Turret] {LIGHTBLUE}Round limit reached for turrets! (Limit: %i)", RoundUse);
			return Shop_Raw;
	 	}

	 	if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			RoundUsed[client]++;
			DroneGun(client);
			return Shop_UseOn;
		}
		else CGOPrintToChat(client, "{GREEN}[Turret] {LIGHTBLUE}You must be alive!");
		return Shop_Raw;
}

public Action TurretCMD(client, args)
{	
	if (!client) return Plugin_Continue;

	if(!Shop_UseClientItem(client, idTurret))
	{
		CGOPrintToChat(client, "{GREEN}[Turret] {RED}Not enough turrets!");
	}
	return Plugin_Handled;
}

public RoundStart(Handle event, const char[] name, bool donBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		RoundUsed[i] = 0;
	}
}

public DroneGun(client)
{
	int iEntity = CreateEntityByName("dronegun");
	float fOrigin[3], fAngles[3];
	SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);
	TR_TraceRayFilter(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, TraceFilterPlayers, client);

	if(TR_DidHit())
	{
		TR_GetEndPosition(fOrigin, INVALID_HANDLE);
		TR_GetPlaneNormal(INVALID_HANDLE, fAngles);
		GetVectorAngles(fAngles, fAngles);

		fAngles[0] += 90.0;

		DispatchKeyValue(iEntity, "solid", "6");
		DispatchKeyValueVector(iEntity, "origin", fOrigin);
		DispatchKeyValueVector(iEntity, "angles", fAngles);

		DispatchSpawn(iEntity);
	}
}

bool TraceFilterPlayers(int iEntity, int iContentsMask, int iData)
{
	return iEntity != iData && iEntity > MaxClients;
}