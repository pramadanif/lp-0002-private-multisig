# Bukti: siklus penuh LP-0002 di LEZ testnet publik

Deployment yang berlaku ada di [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md) — dibuat ulang
2026-09-08T15:25:14Z setelah testnet di-reset, dan **masih hidup**: keluaran di bawah ini diambil
2026-09-09 pukul 01:5x WIB dengan menjalankan ulang skrip yang sama.

Jalankan sendiri:

```bash
./scripts/verify-onchain.sh          # membaca hanya data publik; exit 0 kalau semuanya cocok
```

## Keluaran `verify-onchain.sh` (exit 0)

```
  rpc           : https://testnet.lez.logos.co
  config_hash   : 99cff7fa1f0c4fa267f29d34baafd720906a0e4259e013bc2ca42ac53498fbe4
  proposal_seed : f47f48e87e171ea02816f28fe542e50677a36f23f948e7956db994a9aefba255

  node reachable: yes

  config PDA   : 4ZKN1S7R8F9V2fJEzDz65ogabhDi8sDS82W5i4mADZxt
  proposal PDA : 32Te128ntLW4wSbT6xDb7SYha7q2g8EjFDYTUoDKHEDF
  config       : 2-of-3, owner ok, rehashes to its own address
  verifier     : matches the deployed membership program (ADR-002)
  proposal     : 2 approvals of 2 required, executed, all nullifiers distinct
  FULL M       : evidence uses the full threshold, not a lowered tier (H13/W15)
  payment      : 9NJmD3awoi9FT1yxZFMCvPxuHDcedZbK6LoZ9ZyhAC1J holds 60, covering the 60 approved (INV-7)
  treasury     : 40 (no expected remainder supplied)
  privacy      : proposal holds a count + nullifiers, no member identity (P-F2)

  VERIFIED from public chain data alone.

  transaction variants:
  2 privacy-preserving transaction(s) — approvals really did take the private path
```

Yang diperiksa skrip itu, semuanya dari data publik:

- config account **rehash ke alamatnya sendiri** (INV-3), jadi tidak bisa dipalsukan di alamat sah;
- verifier yang dirujuk config **sama** dengan program membership yang ter-deploy (ADR-002);
- ambang **penuh** 2-of-3 — bukan tier yang diturunkan agar mudah lolos (H13/W15);
- INV-7: yang menerima 60 adalah **penerima yang ditulis proposal**, dibaca dari proposal, bukan
  dari argumen; nilai 0 ditolak supaya pemeriksaan tidak jadi hampa;
- proposal hanya menyimpan cacah + nullifier, **tidak ada identitas anggota** (P-F2);
- dua transaksi persetujuan benar-benar bervarian privacy-preserving.

## Saldo, dibaca langsung dari chain

```
treasury 4ZKN1S7R8F9V2fJEzDz65ogabhDi8sDS82W5i4mADZxt : 100 -> 40
payee    9NJmD3awoi9FT1yxZFMCvPxuHDcedZbK6LoZ9ZyhAC1J :   0 -> 60
```

Kedua sisi perpindahan terlihat di dua akun yang dimiliki dua program berbeda.

## Modul Basecamp membaca akun yang sama

`./scripts/check-basecamp-contract.sh` dengan `PMSIG_CONTRACT_LIVE=1` memanggil slot `fetchConfig`
milik plugin — jalur yang persis sama dengan menekan ↻ di Basecamp — terhadap deployment di atas:

```
  ok     fetchConfig filled the config property
         decoded: {"m":2,"member_root":"Public/6LTswhS1qGGqp17nCvCqMQhUpeFNCkB7jZav6oJfXCE2",…,
                   "n":3,"proposal_count":"0","version":1}
  ok     the fetched multisig is the deployed 2-of-3
```

Jadi yang tampil di panel Config adalah 2-of-3 yang sama dengan yang diverifikasi di atas, bukan
data contoh.

## Run sebelum reset

Deployment pertama (config PDA `n3HuidKX…`, payee `AwB9sZAR…`) sudah hilang bersama reset testnet.
Transaksinya tidak lagi bisa dibuka, jadi tidak dipakai sebagai bukti di mana pun; yang berlaku
hanya yang di atas.
