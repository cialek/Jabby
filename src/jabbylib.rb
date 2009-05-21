#Biblioteka umozliwiajaca komunikacje z serwerem Jabbera
require 'xmpp4r'
require 'xmpp4r/roster'
require 'xmpp4r/roster/iq/roster'
require 'kontakt.rb'
include Jabber

#Klasa odpowiedzialna za komunikacje z serwerem,
#zawiera wszystkie mozliwe operacje dostepne w programie
class Jabbylib
#Inicjalizacja klasy
  def initialize args={}
	@lista_wiad=0
  end
#Umozliwia wysylanie wiadomosci do danego uzytkownika
#jid [Jabber::JID] adres kontaktu do ktorego ma zostac wyslana wiadomosc
#wiadomosc [String] wiadomosc do wyslania
#typ [String] typ wiadomosci do wyslania
  def wyslij_wiadomosc(jid,wiadomosc,typ=:chat)
	kontakty(jid) do |znajomy|
		unless subskryp? znajomy
			dodaj_do_listy(znajomy.jid)
			return dodaj_do_wyslania_po_akceptacji(znajomy.jid,wiadomosc,typ)
		end
		wiad=Message.new(znajomy.jid)
		wiad.type=typ
		wiad.body=wiadomosc
		wyslij(wiad)
	end
  end
#Loguje uzytkownika do konta
#jids [String] adres konta (jid@serwer[/zasob])
#haslo [String] haslo do konta
  def loguj(jids,haslo)
	jid=JID::new(jids)
	@klient=Client::new(jid)
	@klient.connect
	@klient.auth(haslo)
	@klient.send(Presence.new.set_type(:available))
	@wiadomosci_do_wyslania=Queue.new
	def_callback
	sleep(1)
	Thread.new{
		while(true)
			next if @wiadomosci_do_wyslania.length<1
			wiadomosci=[@wiadomosci_do_wyslania.pop]
			wiadomosci.each{ |wiadomosc|
				if subskryp?(JID::new(wiadomosc[:do]))
					wyslij_wiadomosc(wiadomosc[:do],wiadomosc[:wiadomosc],wiadomosc[:typ])
				else
					@wiadomosci_do_wyslania << wiadomosc
				end
			}
		end
	}
  end
#Zmienia status uzytkownika
#status [String] status do zmiany
#opis [String] opis do ustawienia
#
#Mozliwe statusy do ustawienia
# nil  		- Dostepny
# :away 	- Zaraz wracam
# :chat 	- Pogadam
# :dnd 		- Nie przeszkadzac
# :xa 		- Nieosiagalny
# :unavailable 	- Niedostepny
  def zmien_status(status,opis)
	@status=status
	@opis=opis
	stat=Presence.new(@status,@opis)
	wyslij(stat)
  end
#Zwraca liste kontaktow na serwerze
#Type zwracany Hash{|Jabber::JID,Jabber::RosterItem|}
  def lista_kontaktow
	roster.items
  end
#Dodaje uzytkownika do listy kontaktow
#jid [Jabber::JID] - jid uzytkownika do dodania
  def dodaj_do_listy(*jid)
	kontakty(*jid) do |kontakt|
		next if subskryp?(kontakt)
		kontakt.autoryzacja
	end
  end
#Zwraca wiadomosci ktore zostaly wyslane do uzytkownika
#od ostatniego sprawdzenia
#Typ zwracany: Jabber::Message
  def otrzymane_wiadomosci
	wiadomosci=[]
	while(!@kolejka_wiadomosci.empty?)
		wiadomosc=@kolejka_wiadomosci.pop(true) rescue nil
		break if wiadomosc.nil?
		wiadomosci << wiadomosc
		yield wiadomosc if block_given?
	end
	wiadomosci
  end
#Zwraca zmiany statusow ktore zostaly zmienione przez znajomych na liscie kontaktow
  def zmiany_statusow
	statusy=[]
	while(!@kolejka_statusow.empty?)
		status=@kolejka_statusow.pop(true) rescue nil
		break if status.nil?
		statusy << status
		yield status if block_given?
	end
	statusy
  end
#Zwraca prosby o subskrycje wyslane do uzytkownika
  def prosby_o_subskrypcje
	subskrypcje=[]
	while(!@prosba_subskrypcja.empty?)
		sub=@prosba_subskrypcja.pop(true) rescue nil
		break if sub.nil?
		subskrypcje << sub
		yield sub if block_given?
	end
	subskrypcje
  end
#Akceptuje prosbe o subskrypcje wyslana do uzytkownika
#jid [Jabber::JID] - jid uzytkownika do zaakceptowania
  def akceptuj_subskrypcje(jid)
	roster.accept_subscription(jid)
  end
#Odrzuca prosbe o subskrypcje wyslana do uzytkownika
#jid [Jabber::JID] - jid uzytkownika do odrzucenia
  def odrzuc_subskrypcje(jid)
	roster.decline_subscription(jid)
  end
#Usuwa kontakt z listy znajomych
#jid [Jabber::JID] - jid kontaktu do usuniecia
  def usun_z_listy(*jid)
	kontakty(*jid) do |usun|
		usun.usun_subskrypcje
		req=Iq.new_rosterset
		req.query.add(Roster::RosterItem.new(usun.jid,nil,:remove))
		wyslij(req)
	end
  end
#Wysyla wiadomosc na serwer
  def wyslij(wiadomosc)
	proba=0
	begin
		proba+=1
		@klient.send(wiadomosc)
	rescue
		retry unless proba>3
	end
  end
#Zwraca roster polaczenia, w przypadku braku, tworzy nowy
#Typ zwracany [Jabber::Roster::Helper]
  def roster
	return @roster if @roster
	self.roster=Roster::Helper.new(@klient)
  end
  private
#Metoda zwraca obiekt typu Kontakt z listy kontaktow.
#W przypadku braku kontaktu na liscie zostaje on dodany,
#a nastepnie wysylane jest do kontaktu zapytanie o autoryzacje
  def kontakty(*kontakt)
	@kontakty||={}
	k=[]
	kontakt.each do |kon|
	   jid=kon.to_s
	   unless @kontakty[jid]
		@kontakty[jid]=kon.respond_to?(:autoryzacja) ? kon : Kontakt.new(self,kon)
	   end
	   yield @kontakty[jid] if block_given?
	    k << @kontakty[jid]
	end
	k.size > 1 ? k : k.first
  end
#Dodaje wiadomosc do kolejki oczekujacej na akceptacje aubskrypcji
  def dodaj_do_wyslania_po_akceptacji(jid,wiadomosc,typ)
	wiad={:do => jid, :wiadomosc => wiadomosc, :typ => typ}
	@wiadomosci_do_wyslania << wiad
  end
  def roster=(nowy)
	@roster=nowy
  end
#Rejestruje podstawowe callback'i
  def def_callback
	roster.add_query_callback do |iq|
	end
	@kolejka_statusow=Queue.new
	@updt={}
	@mutex=Mutex.new
	roster.add_presence_callback do |item,stary,nowy|
		@kolejka_statusow << nowy
	end
	@kolejka_wiadomosci=Queue.new
	@klient.add_message_callback do |wiadomosc|
		@kolejka_wiadomosci << wiadomosc unless wiadomosc.body.nil?
	end
	@prosba_subskrypcja=Queue.new
	roster.add_subscription_request_callback do |rost,status|
		if status.type==:subscribe		
			@prosba_subskrypcja << status
		end
	end
	@nowe_subskrypcje=Queue.new
	roster.add_subscription_callback do |rost,status|
		if status.type==:subscribed
			@nowe_subskrypcje<<[rost,status]
		end
	end
		
  end
  def subskryp?(jid)
	kontakty(jid) do |kontakt|
		return kontakt.subskrypcja?
	end
  end

end
