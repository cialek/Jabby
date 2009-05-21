require 'jabbylib.rb'
#Klasa pelni role interfejsu uzytkownika.
#Obsluguje funkcje klasy Jabbylib
class Api
#Inicjalizacja klasy. W konstruktorze nastepuje pobranie danych do logowania
#oraz logowanie do serwera
  def initialize
	puts "Witam w programie Jabby v0.3"
	puts "Prosze o wpisanie loginu oraz hasla"
	@jabber=Jabbylib.new  
	begin
		pobierz_dane
		@jabber.loguj(@jid.split('\n')[0],@haslo)
	rescue
		puts "Nie mozna zalogowac, prosze sprawdzic dane oraz polaczenie internetowe"
		retry
	end
	@chat=0
  end
#Funkcja pobierajaca ze standardowego wyjscia nazwe konta oraz haslo
  def pobierz_dane
	print "Podaj nazwe konta(jid@serwer[/zasob]): "
	@jid=gets.strip
	print "Podaj haslo: "
	@haslo=gets.strip
  end
#Funkcja odpowiedzialna za przeksztalcenie statusu w protokole 
#na bardziej dostepny, dla uzytkownika, sposob
#stat [String] - status
  def statusParse(stat)
	case stat
	  when :away : return "Zaraz wracam"
	  when nil : return "Dostepny"
	  when :chat : return "Pogadam"
	  when :dnd : return "Nie przeszkadzac"
	  when :xa : return "Nieosiagalny"
	  when :unavailable : return "Niedostepny"
	end
	"Nieoczekiwany blad"
  end
#Zapisuje historie do pliku
#jid [String] - nazwa konta kontaktu (nazwa dla pliku historii)
#wiad [String] - wiadomosc do zapisania
  def zapisz_historie(jid,wiad)
	plik=File.new("historia/#{jid}","a+")
	plik.write(wiad)
	plik.write("\n")
	plik.close
  end
#Sprawdza nowe zdarzenia przeslane do klienta
#np. nowe wiadomosci, statusy, prosby o autoryzacje
  def odbierz
	wiadomosci=@jabber.otrzymane_wiadomosci
	if !wiadomosci.empty? then
		puts "\nOtrzymane wiadomosci: "
		wiadomosci.each do |wiadomosc|
			puts "#{wiadomosc.to}:\n#{wiadomosc.body}"
			zapisz_historie(wiadomosc.from.to_s.split('/')[0],"#{wiadomosc.from.to_s.split('/')[0]}:\n#{wiadomosc.body}")
		end
	end
	statusy=@jabber.zmiany_statusow
	if !statusy.empty? then
		puts "\nZmiany statusow:"
		statusy.each do |s|			
			puts "Znajomy #{s.from.to_s.split('/')[0]} zmienil status na #{statusParse(s.show)}#{s.status ? "z opisem \"#{s.status}\"" : ""}"
		end
	end
	sub=@jabber.prosby_o_subskrypcje
	if !sub.empty? then
		puts "\nProsby o subskrypcje:"
		sub.each do |s|
			puts "#{s.from} prosi o subskrypcje"
		end
	end
	puts
  end
#Wyswietla tekst o polecenie
  def pytanie#:nodoc:
	puts "Podaj polecenie (help, zeby wyswietlic pomoc)"
  end
#Glowna funkcja klasy pobierajaca komenta i przekazujaca ja do funkcji parsujacej
  def komenda
	pytanie if @chat==0
	dzialaj=true
	kom=gets
	if !(parsuj(kom)) then
		dzialaj=false
	end
	odbierz	
	return dzialaj
  end
#Funkcja parsujaca wpisana komende, w zaleznosci od polecenia
#wywoluje inna funkcje.
  def parsuj(kom)
	slowa=kom.split
	if slowa.length==0 then 
		blad
		return true
	end
	case slowa[0]
		when "help": help
				return true
		when "dodaj": if @chat==1 then 
				wyslijchat(slowa) 
				return true
			      end
			      if slowa.length==2 then
				dodaj(slowa[1])
			      else
				blad
			      end
		when "usun": if @chat==1 then 
				wyslijchat(slowa) 
				return  true
			     end
			     if slowa.length==2 then
				usun(slowa[1])
			     else
				blad
			     end
		when "lista": if @chat==1 then 
				wyslijchat(slowa) 
				return  true
			      end
			      if slowa.length==1 then
				lista
			      else
				blad
			      end
		when "historia": if @chat==1 then 
				   wyslijchat(slowa) 
				   return true
			      	 end
				 if slowa.length==2 then
					historia(slowa[1])
			         else
					blad
			         end
		when "chat":  if @chat==1 then 
				wyslijchat(slowa) 
				return true
			      end
			      if slowa.length==2 then
				if @chat==1 then
					puts "Nie mozna zaczac nowego czatu prowadzac inny, najpierw zakoncz obecny"
					return	true
				end
				@chat=1			
				chat(slowa[1])
			      else
				blad
			      end
		when "wiadomosc": if @chat==1 then 
					wyslijchat(slowa) 
					return true
			      	  end
				  if slowa.length>2 then
					wiadomosc(slowa)
			      	  else
					blad
			      	  end
		when "!anulujchat": if  @chat==0 then
					blad
				    else
					@chat=0
				    end
		when "koniec": if @chat==1 then 
					wyslijchat(slowa) 
					return true
			       end
			       return false
		when "status": if @chat==1 then 
					wyslijchat(slowa) 
					return true
			       end
			       if slowa.length<2&&slowa.length>3 then
					blad
					return true
			       end
			       status(slowa[1],slowa[2])
		when "akceptuj": if @chat==1 then 
					wyslijchat(slowa) 
					return true
			       	   end
				   if slowa.length!=2 then
					blad
					return true
				   end
				   akceptuj(slowa[1])
		when "odrzuc": if @chat==1 then 
					wyslijchat(slowa) 
					return true
			       	   end
				   if slowa.length!=2 then
					blad
					return true
				   end
				   odrzuc(slowa[1])
		else
			if @chat==1
				wyslijchat(slowa)
			else
				blad
			end
		end
	return true
  end
#Funkcja akceptujaca prosbe o subskrypcje
#jids [String] - jid kontaktu
  def akceptuj(jids)
	jid=JID::new(jids)
	@jabber.akceptuj_subskrypcje(jid)
  end
#Funkcja odrzucajaca prosbe o subskrypcje
#jids [String] - jid kontaktu
  def odrzuc(jids)
	jid=JID::new(jids)
	@jabber.odrzuc_subskrypcje(jid)
  end
#Funkcja zmieniajaca status oraz opis (opcjonalnie)
#status [String] - status do zmiany
#opis [String] - opis do ustawienia
  def status(status,opis)
	case status
		when "dostepny": stat=nil
		when "zw":	 stat=:away
		when "pogadam":  stat=:chat
		when "np":	 stat=:dnd
		when "nieosiagalny":	 stat=:xa
	else
		blad
		return
	end
	@jabber.zmien_status(stat,opis)
  end
#Funkcja otwierajaca chat z wybranym uzytkownikiem
#jids [String] - jid kontaktu
  def chat(jids)
	jid=JID::new(jids)
	@chatjid=jid
  end
#Wysyla tekst do wczesniej zdefiniowanego uzytkownika
#w funkcji chat()
#text [String] -tekst do wyslania
  def wyslijchat(text)
	do_wyslania=String.new("")
	text.each{|txt|
		do_wyslania+=txt
		do_wyslania+=" "
	}
	@jabber.wyslij_wiadomosc(@chatjid,text,:chat)
	zapisz_historie(@chatjid.to_s,"#{@jid}:\n#{text}")
  end
#Dodaje uzytkownika do listy
#jids [String] - jid kontaktu
  def dodaj(jids)
	jid=JID::new(jids)
	@jabber.dodaj_do_listy(jid)
  end
#Usuwa uzytkownika do listy kontaktow
  def usun(jids)
	jid=JID::new(jids)
	@jabber.usun_z_listy(jid)
  end
#Wyswietla liste kontaktow
  def lista
	puts "Lista kontaktow:"
	if @jabber.lista_kontaktow.empty? then
		puts "Brak kontaktow na liscie"
		return
	end
	@jabber.lista_kontaktow.keys.each{|kontakt|
		puts kontakt
	}
  end
#Wyswietla historie z uzytkownikiem
#jids [String] - jid kontaktu
  def historia(jid)
	plik=File::new("historia/#{jid}","r")
	if plik.nil? then
		puts "Brak historii z kontaktem #{jid}"
		return
	end
	puts plik.read
  end
#Wysyla wiadomosc do uzytkownika
#slowa [Array] - slowa[0] - polecenie, slowa[1] - uzytkownik, slowa[2..] - wiadomosc
  def wiadomosc(slowa)
	jid=JID::new(slowa[1])
	i=0
	do_wyslania=String.new("")
	slowa.each{|txt|
		if i>1 then
			do_wyslania+=txt+" "
		end
		i+=1
	}
	@jabber.wyslij_wiadomosc(jid,do_wyslania,:normal)
	zapisz_historie(jid.to_s,"#{@jid}:\n#{do_wyslania}")
  end
#Wyswietla pomoc
  def help
	puts "Polecenie argumenty [opcjonalne argumenty] - opis:"
	puts "help 			 - wyswietla ta pomoc"
	puts "wiadomosc uzytkownik tresc - wysyla pojedyncza wiadomosc do uzytkownika"
	puts "chat uzytkownik 		 - tworzy rozmowe z uzytkownikiem, po wydaniu polecenia wystarczy pisac, wszystko co zostanie napisane bedzie wyslane do uzytkownika"
	puts "!anulujchat         	 - wychodzi z trybu \"chat\""
	puts "dodaj uzytkownik    	 - dodaje uzytkownika do listy znajomych"
	puts "usun uzytkownik     	 - usuwa uzytkownika z listy znajomych"
	puts "akceptuj uzytkownik 	 - akceptuje prosbe uzytkownika o subskrypcje"
	puts "odrzuc uzytkownik   	 - odmawia subskrypcji uzytkownikowi"
	puts "lista                      - pokazuje liste znajomych"
	puts "status nowy_status [opis]  - ustawia status na podany wraz z opisem. Lista dostepnych statusow: "
	puts "\tdostepny     - Dostepny"
	puts "\tpogadam      - Pogadam"
	puts "\tnp           - Nie przeszadzac"
	puts "\tzw           - Zaraz wracam"
	puts "\tnieosiagalny - Nieosiagalny"
	puts "koniec 			 - wychodzi z programu"

  end
#Wyswietla blad o wpisaniu blednego polecenia
  def blad
	puts "Bledne polecenie, wpisz help jezeli nie wiesz jak uzywac programu"
  end
end
