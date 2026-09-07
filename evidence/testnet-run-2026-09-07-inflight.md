# Run testnet 2026-09-07 — berhenti di approval 1

Dicatat sebelum skrip selesai, supaya tidak hilang kalau ia mati di tengah.
Kalau dompet menyerah menunggu konfirmasi, transaksinya belum tentu ditolak:
proof sudah di sequencer dan bisa masuk blok belakangan. Cek ulang hash di bawah
sebelum memutuskan mengulang — mengulang berarti membuang proof 20 menit.

| langkah | tx | catatan |
|---|---|---|
| deploy membership | fe3a65ee4127a821847514d0350df479c86cb9b6d14c399c5608b36dde333fdc | blok 38661 |
| deploy multisig | ef9029b2a9d4ef8c261e02af21b9a099ceba510a58a05407ff4a60714bb08d4e | blok 40565 |
| create_multisig | dc67a3cfa3f8b340c22adaab6e40996165a99297ac8673e151273a97aaf783b7 | terkonfirmasi |
| payee init | 525ac76c7c991a06a036ebaf0062d4eac2451c2cad9d7e430e9230a4214634ea | terkonfirmasi |
| approve 1 | 1770532fc48259ede1c532dcb14b63e6cb1fc98c19f9abec0e1c803c9f6a91b8 | privacy-preserving, TIDAK terkonfirmasi dalam 30 blok |

## Keadaan on chain setelah run berhenti

Semua langkah sebelum approval berhasil dan permanen:

- payer 200 -> 100 (mendanai treasury)
- treasury `EzaFmhEoNE9KGpvZVmbgtDdpYhwH32kwxssR2iWis6mX` = 100
- multisig 2-of-3 ada, proposal ada, payee dibuat dan di-init

Yang kurang hanya dua approval dan execute. Menjalankan ulang seluruh skrip
salah dua kali: parameter deterministik akan menabrak akun yang baru dibuat,
dan namespace baru membuang treasury 100 yang sudah didanai sementara payer
hanya punya 100 tersisa.

## Sebab yang sudah tertutup (tanpa run tambahan)

- versi circuit testnet cocok v0.2.4, diperiksa hari yang sama
- kedua PDA kosong sebelum run, jadi bukan tabrakan
- bukan "terlalu besar": sequencer lokal memakai `max_block_size` 1 MiB yang
  sama dan menerima transaksi sebentuk ini tanpa satu pun penundaan
- akun shielded bersaldo 0 juga di dompet lokal yang berhasil
- transaksi tidak cacat: CI meloloskan siklus penuh dengan biner reproducible
  yang sama di sequencer standalone

Tersisa perebutan ruang blok di testnet publik. LEZ menunda transaksi yang tidak
cukup ruang ke blok berikutnya, berulang; alasan penolakan sebenarnya, kalau ada,
hanya muncul di log node yang bukan milik kita.

## Parameter (deterministik dari dompet + ImageID)
```
config_hash   = f8c4c3bd0145c054ba8448aa062085a21792edc04806cec151a36ea6ac6c1ce6
proposal_seed = dd09c20dcefa710c567c3d80a04a7a1fcf5c1e8a89f3a564f7665ad1345551b9
config PDA    = EzaFmhEoNE9KGpvZVmbgtDdpYhwH32kwxssR2iWis6mX
proposal PDA  = 2wTEvSovQcfXXBQFLAJmWGWztJQbcNsgUsjh17A1zq3M
```
