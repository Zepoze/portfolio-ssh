---
author: Pierre-Evens Levasseur
date: MM-dd-YYYY
---
# 👋 Salut, moi c’est Pierre-Evens

~~~bash -C
s=$TARGET_MAX_TIMEOUT
m=$((s/60))
s=$((s%60))

printf "> ⏱️  temps de lecture: ~ 2min"

if [[ ! -z "$TARGET_MAX_TIMEOUT" ]]; then
    printf " | ⚙️ Déconnexion automatique dans "
    ((m>0)) && printf "%dmn " "$m"
    ((m==0)) && printf "%ds " "$s"
fi
printf "\n"
~~~

Bienvenue sur mon portfolio accessible en SSH.

🎯 Objectif : alternance  

🛠️  Domaine : administration système / infra / DevOps polyvalent

📍 Rennes et sa périphérie (35)

> **→** flèche droite pour continuer
> **q | ctrl+c** : pour quitter à tout moment
---

## Mon parcours

Pendant 5 ans, j’ai travaillé en :
- support utilisateur
- administration informatique
- maintenance de serveurs

Aujourd’hui, je poursuis ce parcours  
dans le cadre d’un **diplôme d'ingénieur en alternance sur 3 ans**, avec une approche plus technique et structurée.
---

## Ce que m’a appris le terrain

Le support m’a appris à :
- diagnostiquer sous pression
- prioriser efficacement
- expliquer simplement
- automatiser ce qui revient trop souvent

Ces réflexes guident encore ma façon de travailler.
---

## Pourquoi l’infrastructure et le DevOps

**J’aime :**
- comprendre comment les systèmes fonctionnent vraiment
- fiabiliser plutôt que de bricoler
- automatiser pour réduire les erreurs humaines

**Mon objectif :** concevoir et maintenir des environnements simples, lisibles et maintenables.

---

## Compétences — infrastructure

- Linux, Windows Server
- Virtualisation
- Ansible
- AWS
- Terraform

**Je cherche à :**

- versionner l’infrastructure
- simplifier le déploiement
- garder des architectures compréhensibles
---

## Compétences — développement

Langages & scripting :
- Go
- Python
- React, Node.js
- Bash, PowerShell

Je les utilise principalement pour :
- automatiser
- créer des outils internes
- améliorer la fiabilité des systèmes

---

## Comment je travaille

- je privilégie la clarté à la complexité
- je préfère une solution robuste à une solution brillante
- je n'ai pas peur de me tromper ou de ne pas savoir
---

## Ce que je recherche

Une alternance qui me permettra :
- de monter en compétences en infra / DevOps
- de travailler sur des systèmes réels
- d’apprendre auprès d’équipes expérimentées
- d’être utile rapidement
---
## Ce projet SSH

Ce portfolio est volontairement simple.

- accès via SSH
- aucun shell n'est exposé
- déploiement automatisé sur AWS
- infrastructure déclarative

🎯 **Objectif** : montrer ma manière de penser et créer un projet proche d'une production réaliste.

> Plus de détail [juste ici ->](https://github.com/zepoze/portfolio-ssh)

---

## Et maintenant ?

- 🐙 GitHub : https://github.com/zepoze  
- 📫 Contact : contact@zepoze.fr  

Merci d'avoir pris le temps.  
> Déconnexion avec Ctrl+C.
