Le connecteur cible Nedap AEOS permet de connecter Nedap AEOS aux systèmes sources que vous utilisez via la solution de gestion des identités et des accès (GIA) HelloID de Tools4ever. Cette intégration avec l’application web de contrôle d’accès améliore considérablement la sécurité physique de vos locaux et de vos actifs. Par exemple, elle permet d’attribuer automatiquement les droits d’accès appropriés aux nouveaux employés, leur permettant ainsi d’accéder aux espaces nécessaires dès leur arrivée. Cet article détaille les possibilités et avantages de cette connexion.

## Qu’est-ce que Nedap AEOS ?

Nedap AEOS ne se contente pas de garantir que seules les bonnes personnes ont accès aux bonnes portes et aux bons espaces, mais propose également des outils avancés de surveillance. La plateforme fournit des informations en temps réel sur l’état de la sécurité et génère des alertes, par exemple lorsqu’une porte reste ouverte trop longtemps ou en cas de défaillances techniques. Vous pouvez définir à l’avance comment gérer ces alertes : automatiquement ou manuellement. De plus, il est possible d’établir des protocoles spécifiques pour répondre uniformément à chaque type d’alerte.

## Pourquoi connecter Nedap AEOS à vos systèmes ?

Pour que vos employés soient immédiatement opérationnels, il est essentiel qu’ils aient accès aux espaces nécessaires dès leur premier jour. Par ailleurs, lorsque des employés quittent l’entreprise, leurs droits d’accès doivent être révoqués rapidement pour éviter tout risque de sécurité. Grâce à l’intégration entre vos systèmes sources et Nedap AEOS via HelloID, ces processus sont entièrement automatisés, vous permettant de vous concentrer sur d’autres priorités.

Avec le connecteur Nedap AEOS, il est possible d’intégrer Nedap AEOS à plusieurs systèmes couramment utilisés, tels que : 

*	Active Directory/Entra ID
*	Votre solution de RH (par exemple CPage, ADP, SAP RH, Hexagone, Cegid, Ciril RH, Pléiade, Antibia, etc.)

Vous trouverez plus d’informations sur ces intégrations plus loin dans cet article.

## Comment HelloID s’intègre avec Nedap AEOS

Nedap AEOS fonctionne comme un système cible connecté à HelloID. La solution de GIA communique avec l’API SOAP de Nedap pour créer, mettre à jour et assigner des comptes utilisateurs aux bons modèles d’accès (templates). HelloID gère de manière rapide et efficace les droits d’accès des nouveaux employés. Si nécessaire, elle peut également dissocier un compte d’un template d’accès. La gestion de ces templates est régie par des règles métier.

HelloID peut également indiquer les badges d’accès attribués à un utilisateur spécifique grâce à l’API. Cependant, il convient de noter que le connecteur cible Nedap AEOS ne permet actuellement que la suppression des badges lors de la désactivation d’un compte. L’attribution de badges n’est pas encore possible via le connecteur, et la suppression des comptes est gérée par les processus internes de Nedap AEOS. 

| Modification dans le système source	| Procédure dans Nedap AEOS |
| ---------------------------------- | -------------------------- | 
| Nouveau collaborateur |	HelloID crée automatiquement un compte Nedap AEOS pour le nouvel employé et met à jour ces informations dans le cycle de vie de l’utilisateur. |
| Changement de poste	|	Si les responsabilités d’un employé évoluent, HelloID attribue automatiquement un autre modèle d’accès adapté aux nouvelles fonctions. |


**Création et mise à jour automatiques des comptes nécessaires**

Lorsqu’un nouvel employé rejoint l’entreprise, HelloID crée automatiquement un compte utilisateur dans Nedap AEOS. Si des informations concernant cet employé sont modifiées, la solution ajuste le compte en conséquence, de manière automatique. HelloID met également à jour ces données dans le cycle de vie des utilisateurs en s’appuyant sur les données issues de votre système source.

**Assignation ou suppression des modèles d’accès Nedap AEOS**

En fonction des données issues de votre système source, HelloID peut associer un modèle d’accès spécifique (template) de Nedap AEOS à un employé ou, si nécessaire, lui retirer cet accès. Cela permet de garantir que les autorisations d’accès physiques soient toujours conformes aux besoins opérationnels actuels.

**Prise en charge des champs standard**

Un utilisateur dans Nedap AEOS dispose de plusieurs champs standard qui sont renseignés automatiquement par le connecteur HelloID, en s’appuyant sur les informations provenant de votre système source. Toutefois, il n’est pas possible, avec le connecteur Cible Nedap AEOS, de gérer des exceptions à ces champs standard.

## Fonctionnalités clés d'HelloID pour Nedap AEOS

**Accélération de la création de comptes :** Grâce à l’intégration, la création de comptes Nedap AEOS pour les nouveaux employés est considérablement accélérée. HelloID détecte automatiquement les modifications dans votre système source et repère notamment l’arrivée d’un nouvel employé. Dans ce cas, la solution de GIA crée automatiquement le compte requis dans Nedap AEOS, permettant ainsi d’attribuer facilement le badge d’accès nécessaire. Cela garantit que l’employé dispose, dès son premier jour de travail, des accès aux locaux et espaces requis.

**Gestion sans erreur des comptes :** HelloID automatise la gestion des comptes pour éliminer les erreurs. La solution suit des procédures bien définies et gère les comptes de manière cohérente. En supprimant les interventions manuelles, elle réduit le risque d’erreurs humaines. Ainsi, HelloID garantit un contrôle rigoureux de la gestion des comptes tout en soutenant efficacement vos employés. Toutes les activités liées aux utilisateurs et aux autorisations sont enregistrées automatiquement, vous offrant un registre complet et conforme aux exigences réglementaires.

**Amélioration du service et de la sécurité :** L’intégration permet d’améliorer simultanément votre niveau de service et la sécurité physique. Les employés disposent toujours des accès nécessaires au bon moment, ce qui augmente leur satisfaction et leur productivité. Parallèlement, la sécurité physique est renforcée en limitant les accès non autorisés, notamment en bloquant rapidement les autorisations des employés ayant quitté l’organisation ou en désactivant immédiatement les badges perdus.

## Intégrations possibles entre Nedap AEOS et d’autres systèmes

HelloID facilite l'intégration de divers systèmes avec Nedap AEOS, améliorant et renforçant ainsi la gestion des comptes utilisateurs et des autorisations. Grâce à des processus cohérents et à l'automatisation, cette solution optimise considérablement les opérations. Voici quelques exemples d'intégrations courantes :

* **Connexion Microsoft Active Directory/Entra ID - Nedap AEOS :** L'intégration entre Microsoft Active Directory/Entra ID et Nedap AEOS garantit une synchronisation complète entre votre système source et Nedap AEOS. Cela s’avère particulièrement crucial dans le cadre de l’authentification unique (SSO). Avec le SSO, les utilisateurs n'ont besoin de se connecter qu'une seule fois pour accéder à tous leurs comptes, y compris leur compte Nedap AEOS. Cette approche réduit le nombre de mots de passe à gérer, permettant aux employés d'utiliser des mots de passe plus robustes, renforçant ainsi la sécurité de leurs comptes. Par ailleurs, les risques liés aux mots de passe oubliés sont également diminués, ce qui réduit les besoins en réinitialisations fréquentes.

* **Connexion de votre solution RH - Nedap AEOS :** L'intégration entre votre solution RH et Nedap AEOS améliore la collaboration entre les départements RH et IT. Par exemple, lorsqu'un nouvel employé est ajouté dans le logiciel RH, HelloID crée automatiquement un compte Nedap AEOS pour cet utilisateur. Ce processus entièrement automatisé vous évite toute intervention manuelle et simplifie la gestion des accès.

HelloID prend en charge plus de 200 connecteurs, rendant possible l’intégration de Nedap AEOS avec une grande variété de systèmes sources. Ce portefeuille de connecteurs est en constante évolution, offrant ainsi la possibilité d'intégrer pratiquement tous les systèmes populaires. Vous souhaitez en savoir plus sur les options disponibles ? Retrouvez la liste complète des connecteurs pris en charge <a href="https://www.tools4ever.fr/connecteurs/">ici</a>.
