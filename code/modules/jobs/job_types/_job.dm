/datum/job
	//The name of the job , used for preferences, bans and more. Make sure you know what you're doing before changing this.
	var/title = "NOPE"

	//Job access. The use of minimal_access or access is determined by a config setting: config.jobs_have_minimal_access
	var/list/minimal_access = list()		//Useful for servers which prefer to only have access given to the places a job absolutely needs (Larger server population)
	var/list/access = list()				//Useful for servers which either have fewer players, so each person needs to fill more than one role, or servers which like to give more access, so players can't hide forever in their super secure departments (I'm looking at you, chemistry!)

	//Determines who can demote this position
	var/department_head = list()

	//Tells the given channels that the given mob is the new department head. See communications.dm for valid channels.
	var/list/head_announce = null

	//Bitflags for the job
	var/auto_deadmin_role_flags = NONE

	//Players will be allowed to spawn in as jobs that are set to "Station"
	var/faction = "None"

	//How many players can be this job
	var/total_positions = 0

	//How many players can spawn in as this job
	var/spawn_positions = 0

	//How many players have this job
	var/current_positions = 0

	//Supervisors, who this person answers to directly
	var/supervisors = ""

	//Sellection screen color
	var/selection_color = "#ffffff"


	//If you have the use_age_restriction_for_jobs config option enabled and the database set up, this option will add a requirement for players to be at least minimal_player_age days old. (meaning they first signed in at least that many days before.)
	var/minimal_player_age = 0

	var/outfit = null

	var/exp_requirements = 0

	var/exp_type = ""
	var/exp_type_department = ""

	/// A link to the relevant wiki related to the job. Ex: "Space_law" would link to wiki.blah/Space_law
	var/wiki_page = ""

	//The amount of good boy points playing this role will earn you towards a higher chance to roll antagonist next round
	//can be overridden by antag_rep.txt config
	var/antag_rep = 10

	var/paycheck = PAYCHECK_MINIMAL
	var/paycheck_department = ACCOUNT_CIV

	var/list/mind_traits // Traits added to the mind of the mob assigned this job

	var/display_order = JOB_DISPLAY_ORDER_DEFAULT


	///Levels unlocked at roundstart in physiology
	var/list/roundstart_experience

	///Basically determines whether or not more of the job can be opened.
	var/officer = FALSE

/datum/job/New(new_title, datum/outfit/new_outfit)
	if(new_title)
		title = new_title
		outfit = new_outfit

//Only override this proc
//H is usually a human unless an /equip override transformed it
//do actions on H but send messages to M as the key may not have been transferred_yet
/datum/job/proc/after_spawn(mob/living/H, mob/M)
	//do actions on H but send messages to M as the key may not have been transferred_yet
	if(mind_traits)
		for(var/t in mind_traits)
			ADD_TRAIT(H.mind, t, JOB_TRAIT)
	if(roundstart_experience && ishuman(H))
		var/mob/living/carbon/human/experiencer = H
		for(var/i in roundstart_experience)
			experiencer.mind.adjust_experience(i, roundstart_experience[i], TRUE)


	if(!ishuman(H))
		return
	var/mob/living/carbon/human/human = H
	var/list/gear_leftovers
	if(M.client && (M.client.prefs.equipped_gear && M.client.prefs.equipped_gear.len))
		for(var/gear in M.client.prefs.equipped_gear)
			var/datum/gear/G = GLOB.gear_datums[gear]
			if(G)
				var/permitted = FALSE

				if(G.allowed_roles && H.mind && (H.mind.assigned_role in G.allowed_roles))
					permitted = TRUE
				else if(!G.allowed_roles)
					permitted = TRUE
				else
					permitted = FALSE

				if(G.species_blacklist && (human.dna.species.id in G.species_blacklist))
					permitted = FALSE

				if(G.species_whitelist && !(human.dna.species.id in G.species_whitelist))
					permitted = FALSE

				if(!permitted)
					to_chat(M, "<span class='warning'>Your current species or role does not permit you to spawn with [gear]!</span>")
					continue
				//WS Edit - Fix Loadout Uniforms not spawning ID/PDA
				if(G.slot == ITEM_SLOT_ICLOTHING)
					continue // Handled in pre_equip
				//EndWS Edit - Fix Loadout Uniforms not spawning ID/PDA
				if(G.slot)
					if(!H.equip_to_slot_or_del(G.spawn_item(H, owner = H), G.slot))
						LAZYADD(gear_leftovers, G)
				else
					LAZYADD(gear_leftovers, G)
			else
				M.client.prefs.equipped_gear -= gear

	if(gear_leftovers?.len)
		for(var/datum/gear/G in gear_leftovers)
			var/metadata = M.client.prefs.equipped_gear[G.display_name]
			var/item = G.spawn_item(null, metadata, owner = H)
			var/atom/placed_in = human.equip_or_collect(item)

			if(istype(placed_in))
				if(isturf(placed_in))
					to_chat(M, "<span class='notice'>Placing [G.display_name] on [placed_in]!</span>")
				else
					to_chat(M, "<span class='noticed'>Placing [G.display_name] in [placed_in.name]]")
				continue

			if(H.equip_to_appropriate_slot(item))
				to_chat(M, "<span class='notice'>Placing [G.display_name] in your inventory!</span>")
				continue
			if(H.put_in_hands(item))
				to_chat(M, "<span class='notice'>Placing [G.display_name] in your hands!</span>")
				continue

			var/obj/item/storage/B = (locate() in H)
			if(B)
				G.spawn_item(B, metadata, owner = H)
				to_chat(M, "<span class='notice'>Placing [G.display_name] in [B.name]!</span>")
				continue

			to_chat(M, "<span class='danger'>Failed to locate a storage object on your mob, either you spawned with no hands free and no backpack or this is a bug.</span>")
			qdel(item)

/datum/job/proc/announce(mob/living/carbon/human/H)
	if(head_announce)
		announce_head(H, head_announce)

/datum/job/proc/override_latejoin_spawn(mob/living/carbon/human/H)		//Return TRUE to force latejoining to not automatically place the person in latejoin shuttle/whatever.
	return FALSE

//Used for a special check of whether to allow a client to latejoin as this job.
/datum/job/proc/special_check_latejoin(client/C)
	return TRUE

/datum/job/proc/GetAntagRep()
	. = CONFIG_GET(keyed_list/antag_rep)[lowertext(title)]
	if(. == null)
		return antag_rep


//Gives the player the stuff he should have with his rank
/datum/job/proc/EquipRank(mob/living/living_mob)
	living_mob.job = title

	SEND_SIGNAL(living_mob, COMSIG_JOB_RECEIVED, living_mob.job)

	if(living_mob.mind)
		living_mob.mind.assigned_role = title

	var/display_rank = title
	if(living_mob.client.prefs && living_mob.client.prefs.alt_titles_preferences[title])
		display_rank = living_mob.client.prefs.alt_titles_preferences[title]

	to_chat(living_mob, "<b>You are the [display_rank].</b>")

	var/new_mob = equip(living_mob, null, null, null, living_mob.client)//silicons override this proc to return a mob
	if(ismob(new_mob))
		living_mob = new_mob

	SSpersistence.antag_rep_change[living_mob.client.ckey] += GetAntagRep()

	if(living_mob.client.holder)
		if(CONFIG_GET(flag/auto_deadmin_players) || (living_mob.client.prefs?.toggles & DEADMIN_ALWAYS))
			living_mob.client.holder.auto_deadmin()
		else
			SSjob.handle_auto_deadmin_roles(living_mob.client, title)

	to_chat(living_mob, "<b>As the [display_rank] you answer directly to [supervisors]. Special circumstances may change this.</b>")
	radio_help_message(living_mob)
	//WS Begin - Wikilinks
	if(wiki_page)
		to_chat(living_mob, "<span class='notice'><a href=[CONFIG_GET(string/wikiurl)]/[wiki_page]>Wiki Page</a></span>")
	//WS End

	var/related_policy = get_policy(title)
	if(related_policy)
		to_chat(living_mob,related_policy)
	if(ishuman(living_mob))
		var/mob/living/carbon/human/wageslave = living_mob
		living_mob.add_memory("Your account ID is [wageslave.account_id].")
	if(living_mob)
		after_spawn(living_mob, living_mob) // note: this happens before the mob has a key! living_mob will always have a client, H might not.

	return living_mob


//Don't override this unless the job transforms into a non-human (Silicons do this for example)
/datum/job/proc/equip(mob/living/carbon/human/H, visualsOnly = FALSE, announce = TRUE, datum/outfit/outfit_override = null, client/preference_source)
	if(!H)
		return FALSE
	if(CONFIG_GET(flag/enforce_human_authority) && (title in GLOB.command_positions))
		if(H.dna.species.id != "human")
			H.set_species(/datum/species/human)
			H.apply_pref_name("human", preference_source)
	if(!visualsOnly)
		var/datum/bank_account/bank_account = new(H.real_name, src)
		bank_account.payday(STARTING_PAYCHECKS, TRUE)
		H.account_id = bank_account.account_id

	//Equip the rest of the gear
	H.dna.species.before_equip_job(src, H, visualsOnly)

	// WS Edit - Alt-Job Titles
	if(outfit && preference_source?.prefs?.alt_titles_preferences[title] && !outfit_override)
		var/outfitholder = "[outfit]/[ckey(preference_source.prefs.alt_titles_preferences[title])]"
		if(text2path(outfitholder) || !outfitholder)
			outfit_override = text2path(outfitholder)
	if(outfit_override || outfit)
		H.equipOutfit(outfit_override ? outfit_override : outfit, visualsOnly, preference_source)
	// WS Edit - Alt-Job Titles

	H.dna.species.after_equip_job(src, H, visualsOnly)

	if(!visualsOnly && announce)
		announce(H)

/datum/job/proc/get_access()
	if(!config)	//Needed for robots.
		return src.minimal_access.Copy()

	. = list()

	if(CONFIG_GET(flag/jobs_have_minimal_access))
		. = src.minimal_access.Copy()
	else
		. = src.access.Copy()

	if(CONFIG_GET(flag/everyone_has_maint_access)) //Config has global maint access set
		. |= list(ACCESS_MAINT_TUNNELS)

/datum/job/proc/announce_head(mob/living/carbon/human/H, channels) //tells the given channel that the given mob is the new department head. See communications.dm for valid channels.
	if(H && GLOB.announcement_systems.len)
		//timer because these should come after the captain announcement
		SSticker.OnRoundstart(CALLBACK(GLOBAL_PROC, .proc/addtimer, CALLBACK(pick(GLOB.announcement_systems), /obj/machinery/announcement_system/proc/announce, "NEWHEAD", H.real_name, H.job, channels), 1))

//If the configuration option is set to require players to be logged as old enough to play certain jobs, then this proc checks that they are, otherwise it just returns 1
/datum/job/proc/player_old_enough(client/C)
	var/isexempt = C.prefs.db_flags & DB_FLAG_EXEMPT
	if(isexempt)
		return TRUE
	if(available_in_days(C) == 0)
		return TRUE	//Available in 0 days = available right now = player is old enough to play.
	return FALSE


/datum/job/proc/available_in_days(client/C)
	if(!C)
		return 0
	if(!CONFIG_GET(flag/use_age_restriction_for_jobs))
		return 0
	if(!SSdbcore.Connect())
		return 0 //Without a database connection we can't get a player's age so we'll assume they're old enough for all jobs
	if(!isnum(minimal_player_age))
		return 0

	return max(0, minimal_player_age - C.player_age)

/datum/job/proc/config_check()
	return TRUE

/datum/job/proc/map_check()
	var/list/job_changes = GetMapChanges()
	if(!job_changes)
		return FALSE
	return TRUE

/**
  * Gets the changes dictionary made to the job template by the map config. Returns null if job is removed.
  */
/datum/job/proc/GetMapChanges()
	var/string_type = "[type]"
	var/list/splits = splittext(string_type, "/")
	var/endpart = splits[splits.len]


	var/list/job_changes
	if(!(endpart in job_changes))
		return list()

	return job_changes[endpart]

/datum/job/proc/radio_help_message(mob/M)
	to_chat(M, "<b>Prefix your message with :h to speak on your department's radio. To see other prefixes, look closely at your headset.</b>")

/datum/outfit/job
	name = "Standard Gear"

	var/jobtype = null

	uniform = /obj/item/clothing/under/color/grey
	id = /obj/item/card/id
	back = /obj/item/storage/backpack
	shoes = /obj/item/clothing/shoes/sneakers/black
	box = /obj/item/storage/box/survival

	var/backpack = /obj/item/storage/backpack
	var/satchel  = /obj/item/storage/backpack/satchel
	var/duffelbag = /obj/item/storage/backpack/duffelbag
	var/courierbag = /obj/item/storage/backpack/messenger

	var/alt_uniform

	var/alt_suit = null
	var/dcoat = /obj/item/clothing/suit/hooded/wintercoat

	var/pda_slot = ITEM_SLOT_BELT

/datum/outfit/job/pre_equip(mob/living/carbon/human/H, visualsOnly = FALSE, client/preference_source = null)
	switch(H.backpack)
		if(GBACKPACK)
			back = /obj/item/storage/backpack //Grey backpack
		if(GSATCHEL)
			back = /obj/item/storage/backpack/satchel //Grey satchel
		if(GDUFFELBAG)
			back = /obj/item/storage/backpack/duffelbag //Grey duffel bag
		if(GCOURIERBAG)
			back = /obj/item/storage/backpack/messenger //Grey messenger bag
		if(LSATCHEL)
			back = /obj/item/storage/backpack/satchel/leather //Leather Satchel
		if(DSATCHEL)
			back = satchel //Department satchel
		if(DDUFFELBAG)
			back = duffelbag //Department duffel bag
		if(DCOURIERBAG)
			back = courierbag //Department messenger bag
		else
			back = backpack //Department backpack

	var/holder
	switch(H.jumpsuit_style)
		if(PREF_SKIRT)
			holder = "[uniform]/skirt"
		if(PREF_ALTSUIT)
			if(alt_uniform)
				holder = "[alt_uniform]"
		if(PREF_GREYSUIT)
			holder = "/obj/item/clothing/under/color/grey"
		//WS Edit - Fix Loadout Uniforms not spawning ID/PDA
		if(PREF_LOADOUT)
			if (preference_source == null)
				holder = "[uniform]" // Who are we getting the loadout pref from anyways?
			else
				var/datum/pref_loadout_uniform = null
				for(var/gear in preference_source.prefs.equipped_gear)
					var/datum/gear/G = GLOB.gear_datums[gear]
					if (G.slot == ITEM_SLOT_ICLOTHING)
						pref_loadout_uniform = G.path
				if (pref_loadout_uniform == null)
					holder = "[uniform]"
				else
					uniform = pref_loadout_uniform
		// EndWS Edit - Fix Loadout Uniforms not spawning ID/PDA
		else
			holder = "[uniform]"

	if(text2path(holder))
		uniform = text2path(holder)

	if(holder && text2path(holder))
		uniform = text2path(holder)


	holder = null
	switch(H.exowear)
		if(PREF_ALTEXOWEAR)
			if(alt_suit)
				holder = "[alt_suit]"
			else
				holder = "[suit]"
		if(PREF_NOEXOWEAR)
			holder = null
		if(PREF_COATEXOWEAR)
			holder = "[dcoat]"
		else
			holder = "[suit]"

	if(text2path(holder) || !holder)
		suit = text2path(holder)

/datum/outfit/job/post_equip(mob/living/carbon/human/H, visualsOnly = FALSE, client/preference_source = null)
	if(visualsOnly)
		return

	var/datum/job/J = SSjob.GetJobType(jobtype)
	if(!J)
		J = SSjob.GetJob(H.job)

	var/obj/item/card/id/C = H.wear_id
	if(istype(C))
		C.access = J.get_access()
		shuffle_inplace(C.access) // Shuffle access list to make NTNet passkeys less predictable
		C.registered_name = H.real_name
		if(H.job)
			C.assignment = H.job
		else if(preference_source && preference_source.prefs && preference_source.prefs.alt_titles_preferences[J.title])
			C.assignment = preference_source.prefs.alt_titles_preferences[J.title]
		else
			C.assignment = J.title
		if(H.age)
			C.registered_age = H.age
		C.update_label()
		for(var/A in SSeconomy.bank_accounts)
			var/datum/bank_account/B = A
			if(B.account_id == H.account_id)
				C.registered_account = B
				B.bank_cards += C
				break
		H.sec_hud_set_ID()

	var/obj/item/pda/PDA = H.get_item_by_slot(pda_slot)
	if(istype(PDA))
		PDA.owner = H.real_name
		if(H.job)
			PDA.ownjob = H.job
		else if(preference_source && preference_source.prefs && preference_source.prefs.alt_titles_preferences[J.title])
			PDA.ownjob = preference_source.prefs.alt_titles_preferences[J.title]
		else
			PDA.ownjob = J.title
		PDA.update_label()

/datum/outfit/job/get_chameleon_disguise_info()
	var/list/types = ..()
	types -= /obj/item/storage/backpack //otherwise this will override the actual backpacks
	types += backpack
	types += satchel
	types += duffelbag
	types += courierbag
	return types

//Warden and regular officers add this result to their get_access()
/datum/job/proc/check_config_for_sec_maint()
	if(CONFIG_GET(flag/security_has_maint_access))
		return list(ACCESS_MAINT_TUNNELS)
	return list()
