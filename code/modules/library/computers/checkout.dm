/*
 * Library Computer
 */
/obj/machinery/computer/library/checkout
	name = "Check-In/Out Computer"
	icon = 'icons/obj/library.dmi'
	icon_state = "computer"
	anchored = 1
	density = 1
	req_access = list(access_library) //This access requirement is currently only used for the delete button showing
	var/arcanecheckout = 0
	//var/screenstate = 0 // 0 - Main Menu, 1 - Inventory, 2 - Checked Out, 3 - Check Out a Book
	var/buffer_book
	var/buffer_mob
	var/upload_category = "Fiction"
	var/list/checkouts = list()
	var/list/inventory = list()
	var/checkoutperiod = 5 // In minutes
	var/obj/machinery/libraryscanner/scanner // Book scanner that will be used when uploading books to the Archive

	var/bibledelay = 0 // LOL NO SPAM (1 minute delay) -- Doohl
	var/booklist
	pass_flags = PASSTABLE
	machine_flags = EMAGGABLE | WRENCHMOVE | FIXED2WORK

	hack_abilities = list(
		/datum/malfhack_ability/toggle/disable,
		/datum/malfhack_ability/oneuse/overload_quiet,
		/datum/malfhack_ability/oneuse/emag
	)

/obj/machinery/computer/library/checkout/attack_hand(var/mob/user as mob)
	if(..())
		return
	interact(user)

/obj/machinery/computer/library/checkout/interact(var/mob/user)
	if(interact_check(user))
		return

	var/dat=""
	switch(screenstate)
		if(0)
			// Main Menu

			dat += {"<ol>
				<li><A href='?src=\ref[src];switchscreen=1'>View General Inventory</A></li>
				<li><A href='?src=\ref[src];switchscreen=2'>View Checked Out Inventory</A></li>
				<li><A href='?src=\ref[src];switchscreen=3'>Check out a Book</A></li>
				<li><A href='?src=\ref[src];switchscreen=4'>Connect to External Archive</A></li>
				<li><A href='?src=\ref[src];switchscreen=5'>Upload New Title to Archive</A></li>
				<li><A href='?src=\ref[src];switchscreen=6'>Print a Bible</A></li>
				<li><A href='?src=\ref[src];switchscreen=7'>Print a Manual</A></li>"}
			if(src.emagged)
				dat += "<li><A href='?src=\ref[src];switchscreen=8'>Access the Forbidden Lore Vault</A></li>"
			dat += "</ol>"

			if(src.arcanecheckout)
				new /obj/item/weapon/tome(src.loc)
				to_chat(user, "<span class='warning'>Your sanity barely endures the seconds spent in the vault's browsing window. The only thing to remind you of this when you stop browsing is a dusty old tome sitting on the desk. You don't really remember printing it.</span>")
				user.visible_message("[user] stares at the blank screen for a few moments, his expression frozen in fear. When he finally awakens from it, he looks a lot older.", 2)
				src.arcanecheckout = 0
		if(1)
			// Inventory
			dat += "<h3>Inventory</h3>"
			for(var/obj/item/weapon/book/b in inventory)
				dat += "[b.name] <A href='?src=\ref[src];delbook=\ref[b]'>(Delete)</A><BR>"
			dat += "<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(2)
			// Checked Out
			dat += "<h3>Checked Out Books</h3><BR>"
			for(var/datum/borrowbook/b in checkouts)
				var/timetaken = world.time - b.getdate
				//timetaken *= 10
				timetaken /= 600
				timetaken = round(timetaken)
				var/timedue = b.duedate - world.time
				//timedue *= 10
				timedue /= 600
				if(timedue <= 0)
					timedue = "<font color=red><b>(OVERDUE)</b> [timedue]</font>"
				else
					timedue = round(timedue)

				dat += {"\"[b.bookname]\", Checked out to: [b.mobname]<BR>--- Taken: [timetaken] minutes ago, Due: in [timedue] minutes<BR>
					<A href='?src=\ref[src];checkin=\ref[b]'>(Check In)</A><BR><BR>"}
			dat += "<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(3)
			// Check Out a Book

			dat += {"<h3>Check Out a Book</h3><BR>
				Book: [src.buffer_book]
				<A href='?src=\ref[src];editbook=1'>\[Edit\]</A><BR>
				Recipient: [src.buffer_mob]
				<A href='?src=\ref[src];editmob=1'>\[Edit\]</A><BR>
				Checkout Date : [world.time/600]<BR>
				Due Date: [(world.time + checkoutperiod)/600]<BR>
				(Checkout Period: [checkoutperiod] minutes) (<A href='?src=\ref[src];increasetime=1'>+</A>/<A href='?src=\ref[src];decreasetime=1'>-</A>)
				<A href='?src=\ref[src];checkout=1'>(Commit Entry)</A><BR>
				<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"}
		if(4)
			dat += "<h3>External Archive</h3>"
			if(!SSdbcore.IsConnected())
				dat += "<font color=red><b>ERROR</b>: Unable to contact External Archive. Please contact your system administrator for assistance.</font>"
			else
				num_results = src.get_num_results()
				num_pages = Ceiling(num_results/LIBRARY_BOOKS_PER_PAGE)
				dat += {"<ul>
					<li><A href='?src=\ref[src];id=-1'>(Order book by SS<sup>13</sup>BN)</A></li>
				</ul>"}
				var/pagelist = get_pagelist()

				dat += {"<h2>Search Settings</h2><br />
					<A href='?src=\ref[src];settitle=1'>Filter by Title: [query.title]</A><br />
					<A href='?src=\ref[src];setcategory=1'>Filter by Category: [query.category]</A><br />
					<A href='?src=\ref[src];setauthor=1'>Filter by Author: [query.author]</A><br />
					<A href='?src=\ref[src];search=1'>\[Start Search\]</A><br />"}
				dat += pagelist

				dat += {"<form name='pagenum' action='?src=\ref[src]' method='get'>
										<input type='hidden' name='src' value='\ref[src]'>
										<input type='text' name='pagenum' value='[page_num]' maxlength="5" size="5">
										<input type='submit' value='Jump To Page'>
							</form>"}

				dat += {"<table border=\"0\">
					<tr>
						<td>Author</td>
						<td>Title</td>
						<td>Category</td>
						<td>Controls</td>
					</tr>"}

				for(var/datum/cachedbook/CB in get_page(page_num))
					var/author = CB.author
					var/controls =  "<A href='?src=\ref[src];preview=[CB]'>\[Preview\]</A> <A href='?src=\ref[src];id=[CB.id]'>\[Order\]</A>"
					if(isAdminGhost(user))
						author += " (<A style='color:red' href='?src=\ref[src];delbyckey=[ckey(CB.ckey)]'>[ckey(CB.ckey)])</A>)"
					if(isAdminGhost(user) || allowed(user))
						controls +=  " <A style='color:red' href='?src=\ref[src];del=[CB.id]'>\[Delete\]</A>"
					dat += {"<tr>
						<td>[author]</td>
						<td>[CB.title]</td>
						<td>[CB.category]</td>
						<td>
							[controls]
						</td>
					</tr>"}

				dat += "</table><br />[pagelist]"

			dat += "<br /><A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(5)
			dat += "<h3>Upload a New Title</h3>"
			if(!scanner)
				for(var/obj/machinery/libraryscanner/S in range(9))
					scanner = S
					break
			if(!scanner)
				dat += "<FONT color=red>No scanner found within wireless network range.</FONT><BR>"
			else if(!scanner.cache)
				dat += "<FONT color=red>No data found in scanner memory.</FONT><BR>"
			else

				dat += {"<TT>Data marked for upload...</TT><BR>
					<TT>Title: </TT>[scanner.cache.name]<BR>"}
				if(!scanner.cache.author)
					scanner.cache.author = "Anonymous"

				dat += {"<TT>Author: </TT><A href='?src=\ref[src];uploadauthor=1'>[scanner.cache.author]</A><BR>
					<TT>Category: </TT><A href='?src=\ref[src];uploadcategory=1'>[upload_category]</A><BR>
					<A href='?src=\ref[src];upload=1'>\[Upload\]</A><BR>"}
			dat += "<A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"
		if(7)
			dat += "<H3>Print a Manual</H3>"
			dat += "<table>"

			var/list/forbidden = list(
				/obj/item/weapon/book/manual
			)

			if(!emagged)
				forbidden |= /obj/item/weapon/book/manual/nuclear

			var/manualcount = 0
			var/obj/item/weapon/book/manual/M = null

			for(var/manual_type in typesof(/obj/item/weapon/book/manual))
				if (!(manual_type in forbidden))
					M = manual_type
					dat += "<tr><td><A href='?src=\ref[src];manual=[manualcount]'>[initial(M.title)]</A></td></tr>"
				manualcount++
			dat += "</table>"
			dat += "<BR><A href='?src=\ref[src];switchscreen=0'>(Return to main menu)</A><BR>"

		if(8)

			dat += {"<h3>Accessing Forbidden Lore Vault v 1.3</h3>
				Are you absolutely sure you want to proceed? EldritchTomes Inc. takes no responsibilities for loss of sanity resulting from this action.<p>
				<A href='?src=\ref[src];arccheckout=1'>Yes.</A><BR>
				<A href='?src=\ref[src];switchscreen=0'>No.</A><BR>"}

	var/datum/browser/B = new /datum/browser/clean(user, "library", "Book Inventory Management")
	B.set_content(dat)
	B.open()

/obj/machinery/computer/library/checkout/emag_act(mob/user)
	if(!emagged)
		src.emagged = 1
		if(user)
			to_chat(user, "<span class='notice'>You override the library computer's printing restrictions.</span>")
		return 1
	return

/obj/machinery/computer/library/checkout/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(istype(W, /obj/item/weapon/barcodescanner))
		var/obj/item/weapon/barcodescanner/scanner = W
		scanner.computer = src
		to_chat(user, "[scanner]'s associated machine has been set to [src].")
		for (var/mob/V in hearers(src))
			V.show_message("[src] lets out a low, short blip.", 2)
	else
		return ..()

/obj/machinery/computer/library/checkout/Topic(href, href_list)
	if(..())
		usr << browse(null, "window=library")
		onclose(usr, "library")
		return 1

	if(href_list["pagenum"])
		if(!num_pages)
			page_num = 0
		else
			var/pn = text2num(href_list["pagenum"])
			if(!isnull(pn))
				page_num = clamp(pn, 0, num_pages)

	if(href_list["page"])
		if(num_pages == 0)
			page_num = 0
		else
			page_num = clamp(text2num(href_list["page"]), 0, num_pages)
	if(href_list["settitle"])
		var/newtitle = input("Enter a title to search for:") as text|null
		if(newtitle)
			query.title = sanitize(newtitle)
		else
			query.title = null
	if(href_list["setcategory"])
		var/newcategory = input("Choose a category to search for:") in (list("Any") + library_section_names)
		if(newcategory == "Any")
			query.category = null
		else
			query.category = sanitize(newcategory)
	if(href_list["setauthor"])
		var/newauthor = input("Enter an author to search for:") as text|null
		if(newauthor)
			query.author = sanitize(newauthor)
		else
			query.author = null

	if(href_list["search"])
		num_results = src.get_num_results()
		num_pages = Ceiling(num_results/LIBRARY_BOOKS_PER_PAGE)
		page_num = 0

		screenstate = 4
	if(href_list["del"])
		if(!allowed(usr))
			to_chat(usr,"<span class='warning'>You do not have access to make deletion requests.</span>")
			return
		if(!isAdminGhost(usr)) //old: !usr.check_rights(R_ADMIN)
			to_chat(usr, "<span class='notice'>Your deletion request has been transmitted to Central Command.</span>")
			request_delete_book(getBookByID(href_list["del"]),usr)
		else
			delete_book(getBookByID(href_list["del"]), usr)

	if(href_list["delbyckey"])
		if(!usr.check_rights(R_ADMIN))
			to_chat(usr, "You aren't an admin, piss off.")
			return
		var/tckey = ckey(href_list["delbyckey"])
		var/ans = alert(usr,"Are you sure you wish to delete all books by [tckey]? This cannot be undone.", "Library System", "Yes", "No")
		if(ans=="Yes")
			var/datum/DBQuery/query = SSdbcore.NewQuery("DELETE FROM library WHERE ckey=:tckey", list("tckey" = tckey))
			var/datum/DBQuery/response = query.Execute()
			if(!response)
				to_chat(usr, query.ErrorMsg())
				qdel(query)
				return
			if(response.item.len==0)
				to_chat(usr, "<span class='danger'>Unable to find any matching rows.</span>")
				qdel(query)
				return
			log_admin("LIBRARY: [usr.name]/[usr.key] has deleted [response.item.len] books written by [tckey]!")
			message_admins("[key_name_admin(usr)] has deleted [response.item.len] books written by [tckey]!")
			qdel(query)
			src.updateUsrDialog()
			return

	if(href_list["switchscreen"])
		switch(href_list["switchscreen"])
			if("0")
				screenstate = 0
			if("1")
				screenstate = 1
			if("2")
				screenstate = 2
			if("3")
				screenstate = 3
			if("4")
				screenstate = 4
			if("5")
				screenstate = 5
			if("6")
				if(!bibledelay)

					bibledelay = 1

					var/obj/item/weapon/storage/bible/B = new
					B = new(src.loc)
					if (usr.mind && usr.mind.faith) // The user has a faith
						var/datum/religion/R = usr.mind.faith
						var/obj/item/weapon/storage/bible/HB = R.holy_book
						if (!HB)
							B = chooseBible(R, usr)
						else
							B.icon_state = HB.icon_state
							B.item_state = HB.item_state
						B.name = R.bible_name
						B.my_rel = R

					else if (ticker.religions.len) // No faith
						var/datum/religion/R = input(usr, "Which holy book?") as anything in ticker.religions
						if(!R.holy_book)
							return
						B.icon_state = R.holy_book.icon_state
						B.item_state = R.holy_book.item_state
						B.name = R.bible_name
						B.my_rel = R
					B.forceMove(src.loc)

					spawn(60)
						bibledelay = 0

				else
					visible_message("<b>[src]</b>'s monitor flashes, \"Bible printer currently unavailable, please wait a moment.\"")

			if("7")
				screenstate = 7
			if("8")
				screenstate = 8
	if(href_list["arccheckout"])
		if(src.emagged)
			src.arcanecheckout = 1
		src.screenstate = 0
	if(href_list["increasetime"])
		checkoutperiod += 1
	if(href_list["decreasetime"])
		checkoutperiod -= 1
		if(checkoutperiod < 1)
			checkoutperiod = 1
	if(href_list["editbook"])
		buffer_book = copytext(sanitize(input("Enter the book's title:") as text|null),1,MAX_MESSAGE_LEN)
	if(href_list["editmob"])
		buffer_mob = copytext(sanitize(input("Enter the recipient's name:") as text|null),1,MAX_NAME_LEN)
	if(href_list["checkout"])
		var/datum/borrowbook/b = new /datum/borrowbook
		b.bookname = sanitize(buffer_book)
		b.mobname = sanitize(buffer_mob)
		b.getdate = world.time
		b.duedate = world.time + (checkoutperiod * 600)
		checkouts.Add(b)
	if(href_list["checkin"])
		var/datum/borrowbook/b = locate(href_list["checkin"])
		checkouts.Remove(b)
	if(href_list["delbook"])
		var/obj/item/weapon/book/b = locate(href_list["delbook"])
		inventory.Remove(b)
	if(href_list["uploadauthor"])
		var/newauthor = copytext(sanitize(input("Enter the author's name: ") as text|null),1,MAX_MESSAGE_LEN)
		if(newauthor && scanner)
			scanner.cache.author = newauthor
	if(href_list["uploadcategory"])
		var/newcategory = input("Choose a category: ") in library_section_names
		if(newcategory)
			upload_category = newcategory
	if(href_list["upload"])
		if(scanner)
			if(scanner.cache)
				var/choice = input("Are you certain you wish to upload this title to the Archive?") in list("Confirm", "Abort")
				if(choice == "Confirm")
					if(!SSdbcore.Connect())
						alert("Connection to Archive has been severed. Aborting.")
					else
						var/sqltitle = scanner.cache.name
						var/sqlauthor = scanner.cache.author
						var/sqlcontent = scanner.cache.dat
						var/sqlcategory = upload_category
						var/datum/DBQuery/query = SSdbcore.NewQuery("INSERT INTO library (author, title, content, category, ckey) VALUES (:author, :title, :content, :category, :ckey)",
							list(
								"author" = sqlauthor,
								"title" =  sqltitle,
								"content" = sqlcontent,
								"category" = sqlcategory,
								"ckey" = "[ckey(usr.key)]"
							))
						var/response = query.Execute()
						if(!response)
							to_chat(usr, query.ErrorMsg())
						else
							world.log << response
							log_admin("[usr.name]/[usr.key] has uploaded the book titled [scanner.cache.name], [length(scanner.cache.dat)] characters in length")
							message_admins("[key_name_admin(usr)] has uploaded the book titled [scanner.cache.name], [length(scanner.cache.dat)] characters in length")
						qdel(query)

	if(href_list["id"])
		if(href_list["id"]=="-1")
			href_list["id"] = input("Enter your order:") as null|num
			if(!href_list["id"])
				return

		if(!SSdbcore.IsConnected())
			alert("Connection to Archive has been severed. Aborting.")
			return

		var/datum/cachedbook/newbook = getBookByID(href_list["id"]) // Sanitized in getBookByID
		if(!newbook)
			alert("No book found")
			return
		if((newbook.forbidden == 2 && !emagged) || newbook.forbidden == 1)
			alert("This book is forbidden and cannot be printed.")
			return

		if(bibledelay)
			for (var/mob/V in hearers(src))
				V.show_message("<b>[src]</b>'s monitor flashes, \"Printer unavailable. Please allow a short time before attempting to print.\"")
		else
			bibledelay = 1
			spawn(60)
				bibledelay = 0
			make_external_book(newbook)
	if(href_list["manual"])
		if(!href_list["manual"])
			return
		var/bookid = href_list["manual"]

		if(!SSdbcore.IsConnected())
			alert("Connection to Archive has been severed. Aborting.")
			return

		var/datum/cachedbook/newbook = getBookByID("M[bookid]")
		if(!newbook)
			alert("No book found")
			return
		if((newbook.forbidden == 2 && !emagged) || newbook.forbidden == 1)
			alert("This book is forbidden and cannot be printed.")
			return

		if(bibledelay)
			for (var/mob/V in hearers(src))
				V.show_message("<b>[src]</b>'s monitor flashes, \"Printer unavailable. Please allow a short time before attempting to print.\"")
		else
			bibledelay = 1
			spawn(60)
				bibledelay = 0
			make_external_book(newbook)

	if(href_list["preview"])
		var/datum/cachedbook/PVB = href_list["preview"]
		if(!istype(PVB) || PVB.programmatic)
			return
		var/list/_http = world.Export("http://ss13.moe/index.php/book?id=[PVB.id]")
		if(!_http || !_http["CONTENT"])
			return
		var/http = file2text(_http["CONTENT"])
		if(!http)
			return
		usr << browse("<TT><I>[PVB.title] by [PVB.author].</I></TT> <BR>" + "[http]", "window=[PVB.title];size=600x800")

	add_fingerprint(usr)
	updateUsrDialog()

/obj/machinery/computer/library/checkout/proc/delete_book(var/datum/cachedbook/B, mob/user)
	if(!istype(B) || !user)
		return
	if(!user.check_rights(R_ADMIN))
		return
	var/ans = alert(user, "Are you sure you wish to delete \"[B.title]\", by [B.author]? This cannot be undone.", "Library System", "Yes", "No")
	if(ans!="Yes")
		return
	var/datum/DBQuery/query = SSdbcore.NewQuery("DELETE FROM library WHERE id=:id", list("id" = "[B.id]"))
	var/response = query.Execute()
	if(!response)
		to_chat(user, query.ErrorMsg())
		qdel(query)
		return
	log_admin("LIBRARY: [user.name]/[user.key] has deleted \"[B.title]\", by [B.author] ([B.ckey])!")
	message_admins("[key_name_admin(user)] has deleted \"[B.title]\", by [B.author] ([B.ckey])!")
	src.updateUsrDialog()
	qdel(query)

/obj/machinery/computer/library/checkout/proc/request_delete_book(var/datum/cachedbook/B, mob/requester)
	log_admin("LIBRARY: [requester.name]/[requester.key] requested [B.title] be deleted permanently.")
	var/raw = "LIBRARY: Request to permanently delete [B] from the library database. <A href='?src=\ref[src];preview=[B]'>\[Preview\]</A> <A style='color:red' href='?src=\ref[src];del=[B.id]'>\[Delete\]</A>"
	var/formal = "<span class='notice'><b>  LIBRARY: [key_name(requester, 1)] (<A HREF='?_src_=holder;adminplayeropts=\ref[requester]'>PP</A>) (<A HREF='?_src_=vars;Vars=\ref[requester]'>VV</A>) (<A HREF='?_src_=holder;subtlemessage=\ref[requester]'>SM</A>) (<A HREF='?_src_=holder;adminplayerobservejump=\ref[requester]'>JMP</A>) (<A HREF='?_src_=holder;check_antagonist=1'>CA</A>) (<a href='?_src_=holder;role_panel=\ref[requester]'>RP</a>) (<A HREF='?_src_=holder;BlueSpaceArtillery=\ref[requester]'>BSA</A>) (<A HREF='?_src_=holder;CentcommReply=\ref[requester]'>RPLY</A>):</b> [raw]</span>"
	send_prayer_to_admins(formal, raw, 'sound/effects/msn.ogg', "Centcomm", key_name(requester), get_turf(requester))

/*
 * Library Scanner
 */

/obj/machinery/computer/library/checkout/proc/make_external_book(var/datum/cachedbook/newbook)
	if(!newbook || !newbook.id)
		return
	var/obj/item/weapon/book/B = new newbook.path(src.loc)
	B.icon_state = "book[rand(1,9)]"
	B.item_state = B.icon_state
	if (!newbook.programmatic)
		var/list/_http = world.Export("http://ss13.moe/index.php/book?id=[newbook.id]")
		if(!_http || !_http["CONTENT"])
			return
		var/http = file2text(_http["CONTENT"])
		if(!http)
			return
		B.name = "Book: [newbook.title]"
		B.title = newbook.title
		B.author = newbook.author
		B.dat = http

	src.visible_message("[src]'s printer hums as it produces a completely bound book. How did it do that?")
