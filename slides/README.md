# Slides

La présentation est servie via l'utilitaire `slides` (https://github.com/maaslalani/slides). Elle se base sur `slides.md` et expose le service sur le port `23234`.

## Commandes utiles

```sh
# build
docker build -t ssh-portfolio-slides ./slides

# run
docker run --rm -p 23234:23234 ssh-portfolio-slides
```

Le service est déjà intégré dans `docker-compose.yml` pour simplifier la mise en route.
