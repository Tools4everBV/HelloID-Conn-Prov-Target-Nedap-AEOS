Mit dem **Nedap AEOS Target Connector** verbinden Sie Nedap AEOS über die Identity & Access Management (IAM)-Lösung HelloID von Tools4ever mit den von Ihnen genutzten Quellsystemen. Die Integration mit der webbasierten Anwendung zur Zugangskontrolle hebt die physische Sicherheit Ihrer Gebäude und Vermögenswerte auf ein höheres Niveau. Diese Verbindung stellt unter anderem sicher, dass neuen Mitarbeitern automatisch die richtigen Zugangsrechte zugewiesen werden und sie somit jederzeit die richtigen Räume betreten können. In diesem Artikel erfahren Sie mehr über die Möglichkeiten und Vorteile des Nedap AEOS Target Connector.

## Was ist Nedap AEOS?

Nedap AEOS stellt nicht nur sicher, dass die richtigen Personen Zugang zu den richtigen Türen und Räumen haben, sondern ermöglicht auch eine gezielte Überwachung. So bietet die Plattform aktuelle Informationen über die Sicherheitslage und alarmiert beispielsweise, wenn eine Tür zu lange offen steht oder bei technischen Mängeln. Sie entscheiden, wie auf solche Meldungen reagiert wird; dies kann sowohl automatisch als auch manuell erfolgen. So können Sie im Voraus Anweisungen erstellen, die festlegen, wie auf einen bestimmten Alarm reagiert werden soll. Dies stellt sicher, dass alle AEOS-Nutzer einheitlichen Richtlinien folgen.

## Warum ist die Nedap AEOS-Kopplung praktisch?

Um ihre Arbeit optimal zu verrichten, benötigen Mitarbeiter Zugang zu den richtigen Räumen. Wenn ein neuer Mitarbeiter eingestellt wird, möchten Sie diesen Zugang so schnell wie möglich regeln, damit der neue Mitarbeiter sofort produktiv sein kann. Gleichzeitig möchten Sie sicherstellen, dass ausscheidende Mitarbeiter keinen Zugang mehr zu Räumen haben und ihre Zugriffsrechte rechtzeitig widerrufen werden. Dank der Verbindung zwischen Ihren Quellsystemen und Nedap AEOS über HelloID müssen Sie sich darüber keine Sorgen machen.

Mit dem Nedap AEOS-Connector sind Integrationen mit diversen gängigen Systemen möglich. Dazu gehören: 

* Active Directory/Entra ID
* AFAS

Weitere Informationen zu diesen Integrationen finden Sie weiter unten in diesem Artikel.

## Wie HelloID mit Nedap AEOS integriert

Nedap AEOS wird als Zielsystem mit HelloID gekoppelt. Die IAM-Lösung spricht dabei die SOAP API von Nedap an. Über diese API kann HelloID unter anderem Benutzerkonten erstellen, Daten aktualisieren und ihnen das richtige Zugangstemplate zuweisen. So regelt die Lösung schnell und effizient die korrekten Zugangsrechte für einen neuen Benutzer. Falls erforderlich, kann HelloID ein Konto auch von einem Zugangstemplate entkoppeln. Die Verwaltung dieser Templates erfolgt über Geschäftsregeln. Über die API kann HelloID auch aufzeigen, welche Zugangsausweise einem bestimmten Benutzer zugewiesen wurden.

Hinweis: Der Nedap AEOS Target Connector unterstützt nur das Entfernen eines Ausweises, wenn ein Konto deaktiviert wird. Die Zuweisung von Ausweisen über den Connector ist derzeit nicht möglich. Das Entfernen von Konten erfolgt zudem über Nedap AEOS, das integrierte Möglichkeiten zur Automatisierung dieses Prozesses bietet.

**Automatisches Erstellen und Aktualisieren des erforderlichen Kontos**  
Wenn ein neuer Mitarbeiter eingestellt wird, erstellt HelloID automatisch einen Mitarbeiter in Nedap AEOS. Ändern sich die Mitarbeiterdaten, passt die Lösung das Konto bei Bedarf automatisch an. Basierend auf den Quelldaten wird die IAM-Lösung diese auch im Lifecycle von HelloID aktualisieren.

**Nedap AEOS-Zugangstemplates zuweisen oder entziehen**  
Basierend auf Ihren Quelldaten kann HelloID ein Zugangstemplate von Nedap AEOS an den Mitarbeiter koppeln oder falls erforderlich entziehen.

Ein Benutzer in Nedap AEOS verfügt über eine Reihe von Standardfeldern. Der Connector füllt diese Felder basierend auf den Daten Ihres Quellsystems aus. Ausnahmen hiervon sind mit dem Nedap AEOS Target Connector nicht möglich.

## HelloID für Nedap AEOS hilft Ihnen bei

* **Beschleunigung der Kontoerstellung:** Durch die Integration erstellen Sie Nedap AEOS-Konten für neue Mitarbeiter schneller. HelloID erkennt automatisch Änderungen in Ihrem Quellsystem und stellt somit fest, wenn ein neuer Mitarbeiter eingestellt wird. In diesem Fall erstellt die IAM-Lösung in Nedap AEOS automatisch das benötigte Konto, sodass Sie einfach den erforderlichen Ausweis zuweisen können. So erhält der Mitarbeiter bereits am ersten Arbeitstag Zugang zum Bürogebäude und den benötigten Räumen.

* **Fehlerfreies Kontoverwaltung:** Dank Automatisierung macht HelloID die Kontoverwaltung fehlerfrei. Die IAM-Lösung folgt immer festen Verfahren und verwaltet Konten auf konsistente Weise. Durch Automatisierung sind manuelle Eingriffe nicht mehr nötig und Prozesse sind weniger fehleranfällig. So verhindern Sie menschliche Fehler, machen die Kontoverwaltung fehlerfrei und unterstützen Ihre Mitarbeiter optimal. HelloID protokolliert automatisch alle benutzer- und autorisierungsbezogenen Aktivitäten, sodass Sie über ein umfassendes Logbuch verfügen und jederzeit nachweisen können, dass Sie die geltenden Compliance-Anforderungen erfüllen.

* **Verbesserung Ihres Serviceniveaus und Ihrer Sicherheit:** Mit der Integration verbessern Sie sowohl das Serviceniveau als auch die Sicherheit. So stellen Sie sicher, dass Mitarbeiter jederzeit über den richtigen physischen Zugang verfügen, was die Benutzerzufriedenheit erhöht und Ihre Mitarbeiter optimal unterstützt. Gleichzeitig stärken Sie die physische Sicherheit, indem Sie unbefugten Zugang aktiv verhindern. Nicht nur durch das rechtzeitige Sperren des Zugangs von ausgeschiedenen Mitarbeitern, sondern auch durch beispielsweise das schnelle Deaktivieren verlorener Zugangsmittel.

## Verbindung von Nedap AEOS mit Systemen über HelloID

HelloID ermöglicht die Integration verschiedener Systeme mit Nedap AEOS. Die Integrationen verbessern und stärken die Verwaltung von Benutzerkonten und Berechtigungen, unter anderem durch konsistente Prozesse und Automatisierung. Einige Beispiele für häufige Integrationen sind:

* **Microsoft Active Directory/Entra ID - Nedap AEOS Verbindung:** Die Microsoft Active Directory/Entra ID - Nedap AEOS Verbindung hält Ihr Quellsystem und Nedap AEOS vollständig synchron, was unter anderem im Hinblick auf Single Sign-on (SSO) wichtig ist. Nutzer müssen dank SSO nur einmal einloggen, um Zugang zu den benötigten Konten zu erhalten, darunter auch ihr Nedap AEOS-Konto. Dies bedeutet, dass Mitarbeiter weniger Passwörter verwalten müssen. Einerseits können Mitarbeiter dadurch stärkere Passwörter verwenden, was die Sicherheit ihrer Konten erhöht. Andererseits ist es weniger oft nötig, vergessene Passwörter zurückzusetzen, weil Nutzer weniger verschiedene Passwörter verwenden.

* **AFAS - Nedap AEOS Verbindung:** Die AFAS - Nedap AEOS Verbindung erhöht die Zusammenarbeit zwischen den HR- und IT-Abteilungen. Wenn Sie einen neuen Mitarbeiter zu AFAS hinzufügen, erstellt HelloID beispielsweise automatisch ein Nedap AEOS-Konto für diesen Benutzer. So müssen Sie sich um diesen Prozess nicht kümmern.

HelloID unterstützt mehr als 200 Connectoren. Die IAM-Lösung ermöglicht es daher, eine breite Palette von Quellsystemen mit Nedap AEOS zu verbinden. Unser Portfolio an Connectoren befindet sich in kontinuierlicher Entwicklung und wird ständig erweitert. Sie können dadurch nahezu jedes beliebte System mit HelloID integrieren.