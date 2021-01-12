#if defined _mvpsound_included
 #endinput
#endif
#define _mvpsound_included

public SharedPlugin __pl_mvpsound = 
{
    name = "mvpsound",
    file = "MVPSound.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

/* *******************************************************		************************************************************* 
 *	Checks if the player has music kits. 						*	Проверяет, имеет ли игрок музыкальные наборы.
 *																*	
 *	@param1	- Client index. 									*	@param1	- Индекс клиента.															
 *	@return - Number of music kits.								*	@return - Число музыкальных наборов.	
 *																*
 * ******************************************************** 	* ********************************************************* */	
 native int MVP_GetClientMusicKits(int client);
 
/* ********************************************************		************************************************************* 
 *	Checks if the player has compositions in music kit. 		*	Проверяет, имеет ли игрок композиции в наборе.
 *																*	
 *	@param1	- Client index. 									*	@param1	- Индекс клиента.															
 *	@return - Number of compositions.							*	@return - Число композиций.	
 *																*
 * ******************************************************** 	*********************************************************** */	
 native int MVP_GetClientCompositions(int client);
 
 /* ********************************************************	************************************************************* 
 *	Checks if the player is able to listen to the MVP. 			*	Проверяет, может ли игрок прослушивать MVP.
 *																*	
 *	@param1	- Client index. 									*	@param1	- Индекс клиента.															
 *	@return - True if it can, otherwise false.					*	@return - Истина, если может, иначе ложь.	
 *																*
 * ******************************************************** 	*********************************************************** */	
 native bool MVP_IsClientListen(int client);
 
 
 /* ********************************************************	************************************************************* 
 *	Checks if the player is able to listen to the MVP. 			*	Устанавливает режим прослшуивания музыки MVP.
 *																*	
 *	@param1	- Client index. 									*	@param1	- Индекс клиента.															
 *	@param2	- String buffer for storage.  						*	@param2	- Флаг воспроизведения.																										
 *	@return - None.												*	@return - Ничего не возвращает..	
 *																*
 * ******************************************************** 	*********************************************************** */	
 native void MVP_SetClientPlayMusic(int client, bool flag = true);

#if !defined REQUIRE_PLUGIN
public void __pl_mvpsound_SetNTVOptional()
{
    MarkNativeAsOptional("MVP_GetClientMusicKits");
	MarkNativeAsOptional("MVP_GetClientCompositions");
	MarkNativeAsOptional("MVP_IsClientListen");
	MarkNativeAsOptional("MVP_SetClientPlayMusic");
}
#endif 