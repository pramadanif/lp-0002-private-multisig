# Bukti: siklus penuh LP-0002 di LEZ testnet publik

Diverifikasi 2026-09-08 13:05 UTC terhadap https://testnet.lez.logos.co,
selagi node masih menjawab. Disalin ke sini karena node kemudian mengembalikan 502
(nginx Bad Gateway — backend tidak menjawab), dan indeks explorer ikut berhenti menyusul.

## Transaksi


## Keluaran verify-onchain.sh (exit 0)

```
  config PDA   : n3HuidKXZA76ZpsrDr3NLitRFqQDndr6BHxzaeq7aRH
  proposal PDA : DgPGeMewSSoSJ5jkPMYfZaQTDNuDdiKPB6Q4V6go6j4y
  config       : 2-of-3, owner ok, rehashes to its own address
  verifier     : matches the deployed membership program (ADR-002)
  proposal     : 2 approvals of 2 required, executed, all nullifiers distinct
  FULL M       : evidence uses the full threshold, not a lowered tier (H13/W15)
  payment      : AwB9sZARmYaW6znJMcsCwSoJjnRcvuwE1cKKf8z8Swos holds 60, covering the 60 approved (INV-7)
  treasury     : 40 left, exactly funding minus the 60 paid
  privacy      : proposal holds a count + nullifiers, no member identity (P-F2)

  VERIFIED from public chain data alone.
  2 privacy-preserving transaction(s) — approvals really did take the private path
```

## Saldo, dibaca langsung dari chain

```
treasury n3HuidKXZA76ZpsrDr3NLitRFqQDndr6BHxzaeq7aRH : 100 -> 40
payee    AwB9sZARmYaW6znJMcsCwSoJjnRcvuwE1cKKf8z8Swos :   0 -> 60
```

Kedua sisi perpindahan terlihat di dua akun yang dimiliki dua program berbeda.
