#!/usr/bin/ruby
require 'xmpp4r'
require 'xmpp4r/roster'
include Jabber

#Klasa reprezentujaca pojedynczy kontakt
class Kontakt
#Konstruktor inicjalizuje jid uzytkownika oraz klienta
  def initialize(klient,jid)
     @jid=jid.respond_to?(:resource)? jid : JID.new(jid)
     @klient=klient
  end
#Zwraca czy pomiedzy klientem a kontaktem jest obustronna subskrypcja
  def subskrypcja?
	[:to,:both].include?(subskrypcja)
  end
#Zwraca kontakt z rostera i jego subskrypcje
  def subskrypcja
     rost && rost.subscription
  end
#Zwraca kontakt znajdujacy sie w rosterze
  def rost
	@klient.roster.items[@jid]
  end
#Zwraca jid uzytkownika
  def jid(podst=true)
	podst ? @jid.strip : @jid
  end
#Wysyla prosbe o autoryzacje do uzytkwonika
  def autoryzacja
     prosba=Presence.new.set_type(:subscribe)
     prosba.to=jid
     @klient.wyslij(prosba)
  end
#Usuwa subskrypcje uzytkownika
  def usun_subskrypcje
     usun=Presence.new.set_type(:unsubscribe)
     usun.to=jid
     @klient.wyslij(usun)
     @klient.wyslij(usun.set_type(:unsubscribed))
  end
end

