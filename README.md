# BlueMaia Digital: site

Site de uma página, em 4 línguas (PT/DE/EN/ES), de **BlueMaia Digital**: assistência informática em Lucerna e arredores.

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

## Avaliações de clientes

- O botão «Deixar uma avaliação» envia para `/api/bewertungen`, servido por `avaliacoes/server.py` (Python, só em `127.0.0.1:8093`, atrás do Caddy).
- Cada avaliação fica **pendente**. Só aparece no site depois de aprovada na ferramenta privada **BlueMaia Rechnungen** (secção «Bewertungen»), que não está exposta à internet.
- Dados em `/srv/bluemaia-avaliacoes/data/avaliacoes.sqlite`, fora do repositório (nunca vão para o GitHub). Cópia diária no WD My Cloud, feita pelo Rechnungen.
- Proteção contra spam: campo-armadilha, mínimo de 4 s no formulário, sem links, máx. 3 envios por hora por endereço, máx. 100 pendentes.
- Instalar uma vez na Orange Pi: `bash setup-avaliacoes.sh`; depois, `bash publicar.sh "..."` como sempre.
