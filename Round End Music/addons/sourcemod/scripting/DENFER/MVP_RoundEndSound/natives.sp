public int Native_MVP_GetClientMusicKits(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	
	KeyValues kv = new KeyValues("Players");
	kv.Rewind();
	
	int key = 0;
	
	char SteamID64[18], SteamId[20], IP[16];
	GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64));
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	GetClientIP(client, IP, sizeof(IP), false);
	
	if(kv.ImportFromFile(g_szPathPlayersKeyValues))
	{
		if(kv.GotoFirstSubKey())
		{
			do
			{
				char Section[20];
				kv.GetSectionName(Section, sizeof(Section));
				
				if(StrContains(Section, SteamID64) != -1 || StrContains(Section, SteamId) != -1 || StrContains(Section, IP) != -1) 
				{
					if(kv.GotoFirstSubKey())
					{
						do
						{
							key++;
						}
						while(kv.GotoNextKey()); 
					}
				}
			}
			while(kv.GotoNextKey()); 
		}
	}
	
	delete kv;
	return key;
}

public int Native_MVP_GetClientCompositions(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	
	KeyValues kv = new KeyValues("Players");
	kv.Rewind(); 
	
	int key = 0;
	
	char SteamID64[18], SteamId[20], IP[16];
	GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64));
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
	GetClientIP(client, IP, sizeof(IP), false);
	
	if(kv.ImportFromFile(g_szPathPlayersKeyValues))
	{
		if(kv.GotoFirstSubKey())
		{
			do
			{
				char Section[64];
				kv.GetSectionName(Section, sizeof(Section));
				
				if(StrContains(Section, SteamID64) != -1 || StrContains(Section, SteamId) != -1 || StrContains(Section, IP) != -1) 
				{
					if(kv.GotoFirstSubKey(false)) 
					{
						do
						{
							key++; 
						}
						while(kv.GotoNextKey(false));
					}
				}
			}
			while(kv.GotoNextKey()); 
		}
	}
	
	delete kv;
	return key;
}

public int Native_MVP_IsClientListen(Handle plugin, int args)
{	
	return g_bMVPMusic[GetNativeCell(1)];
}

public int Native_MVP_SetClientPlayMusic(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	bool flag = GetNativeCell(2);
	
	if(flag)
	{
		g_bMVPMusic[client] = true;
	}
	else
	{
		g_bMVPMusic[client] = false;
		
		if(strlen(g_sAudioPlayer) != 0)
		{
			StopSound(client, SNDCHAN_AUTO , g_sAudioPlayer);
		}
	}
}