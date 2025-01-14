/datum/faction/wizard
	name = "Wizard Federation"
	ID = WIZFEDERATION
	initial_role = WIZARD
	late_role = WIZARD
	required_pref = WIZARD
	desc = "A conglomeration of magically adept individuals, with no obvious heirachy, instead acting as equal individuals in the pursuit of magic-oriented endeavours.\
	Their motivations for attacking seemingly peaceful enclaves or operations are as yet unknown, but they do so without respite or remorse.\
	This has led to them being identified as enemies of humanity, and should be treated as such."
	initroletype = /datum/role/wizard
	roletype = /datum/role/wizard
	logo_state = "wizard-logo"
	hud_icons = list("wizard-logo","apprentice-logo")
	default_admin_voice = "Wizard Federation"
	admin_voice_style = "notice"

/datum/faction/wizard/New()
	..()
	load_dungeon(/datum/map_element/dungeon/wizard_den)

/datum/faction/wizard/civilwar
	var/enemy_faction

/datum/faction/wizard/civilwar/forgeObjectives()
	var/datum/objective/destroyfaction/O = new()
	var/datum/faction/target = find_active_faction_by_type(enemy_faction)
	if(!target)
		target = ticker.mode.CreateFaction(enemy_faction, null, 1)
	O.targetfaction = target
	AppendObjective(O)
	..()

/datum/faction/wizard/civilwar/process()
	..()
	var/anywiz = FALSE
	var/converts = FALSE
	for(var/datum/role/R in members)
		if(istype(R,/datum/role/wizard_convert))
			converts = TRUE // still converts in the game
		if(istype(R,/datum/role/wizard) && R.antag.current && !R.antag.current.stat)
			anywiz = TRUE //If one wizard is still not incapacitated
	if(!anywiz && converts)
		for(var/datum/role/wizard_convert/WC in members)
			WC.Drop()

/datum/faction/wizard/civilwar/wpf
	name = "The Wizardly Peoples' Front"
	desc = "The WPF are a faction within the Wizard Federation. The only people they hate more than Nanotrasen are the Peoples' Front for Wizards."
	enemy_faction = /datum/faction/wizard/civilwar/pfw

/datum/faction/wizard/civilwar/pfw
	name = "The Peoples' Front for Wizards"
	desc = "The PFW are a faction within the Wizard Federation. The only people they hate more than Nanotrasen are the Wizardly Peoples' Front."
	enemy_faction = /datum/faction/wizard/civilwar/wpf

/datum/faction/wizard/HandleNewMind(var/datum/mind/M)
	..()
	M.special_role = "Wizard"

/datum/faction/wizard/OnPostSetup()
	if(wizardstart.len == 0)
		for(var/datum/role/wizard in members)
			to_chat(wizard.antag.current, "<span class='danger'>A starting location for you could not be found, please report this bug!</span>")
		log_admin("Failed to set-up a round of wizard. Couldn't find any wizard spawn points.")
		message_admins("Failed to set-up a round of wizard. Couldn't find any wizard spawn points.")
		return 0 //Critical failure.
	..()

/datum/faction/wizard/forgeObjectives()
	for(var/datum/role/R in members)
		R.ForgeObjectives()
		R.AnnounceObjectives()

/datum/faction/wizard/ragin
	accept_latejoiners = TRUE
	var/max_wizards

/datum/faction/wizard/ragin/check_win()
	if(members.len == max_roles)
		return 1

/datum/map_element/dungeon/wizard_den
	file_path = "maps/misc/wizardden1.dmm"
	unique = TRUE

/datum/map_element/dungeon/wizard_den/pre_load()
	file_path = "maps/misc/wizardden[rand(1,5)].dmm"
