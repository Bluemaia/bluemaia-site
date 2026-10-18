# BlueMaia Digital: site

Site de uma página, bilingue (PT/DE), de **BlueMaia Digital**: assistência informática em Lucerna e arredores.

- `public/`: o site (HTML + assets). Não usa cookies, rastreamento nem pedidos externos; a letra (Lexend) está alojada no próprio site.
- `Caddyfile`: servidor web na Orange Pi, só em `127.0.0.1:8081`.
- `setup-orangepi.sh`: instalação na Orange Pi (Ubuntu 24.04).

## Arquitetura

```
GitHub (bluemaia-site) ──git pull a cada 5 min──▶ Orange Pi Zero 2W
                                                   └─ Caddy (127.0.0.1:8081)
                                                        └─ Cloudflare Tunnel ──▶ https://bluemaia.ch
```

Não há portas abertas no router: a Orange Pi liga-se ao Cloudflare de dentro para fora.

## Publicar uma alteração

1. Editar `public/index.html`.
2. `git commit` e `git push` para `main`.
3. A Orange Pi apanha a alteração em até 5 minutos.
