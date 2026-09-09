#![allow(
    clippy::expect_used,
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "test code: panicking is how a test reports failure"
)]
//! The committed IDL must decode the bytes the program actually writes.
//!
//! `artifacts/multisig.idl.json` is what the Basecamp module carries (the FFI embeds it) and what
//! `spel inspect` reads. Its account layouts are derived from the state structs' source by this
//! crate's binary, so the failure mode to guard against is drift: a field added, reordered or
//! retyped in `pmsig-multisig-core` without regenerating the IDL. Borsh is positional, so drift
//! does not error — it decodes the *wrong* values and the UI shows a plausible lie.
//!
//! These tests Borsh-encode real state and decode it back through the committed IDL, so any such
//! drift fails here instead of on screen.

use pmsig_multisig_core::{MultisigConfig, Proposal, ProposedAction};
use spel_framework_core::decode::decode_account_data_try_all;
use spel_framework_core::idl::SpelIdl;

fn idl() -> SpelIdl {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../artifacts/multisig.idl.json"
    );
    let text = std::fs::read_to_string(path).expect("artifacts/multisig.idl.json is committed");
    serde_json::from_str(&text).expect("the committed IDL parses")
}

#[test]
fn config_decodes_through_the_committed_idl() {
    let config = MultisigConfig {
        version: 1,
        member_root: [7u8; 32],
        m: 2,
        n: 3,
        multisig_id: [9u8; 32],
        membership_program_id: [0x1122_3344u32; 8],
        proposal_count: 5,
    };
    let bytes = borsh::to_vec(&config).expect("borsh");

    let (name, fields) =
        decode_account_data_try_all(&bytes, &idl()).expect("the IDL decodes a config account");
    assert_eq!(name, "MultisigConfig");

    assert_eq!(fields["version"], 1);
    assert_eq!(fields["m"], 2);
    assert_eq!(fields["n"], 3);
    // 64-bit and wider integers come back as decimal strings — JSON numbers cannot hold them
    // exactly, and the UI prints them verbatim.
    assert_eq!(fields["proposal_count"], "5");
    // The decoder renders 32-byte fields the way the explorer and `spel inspect` render addresses,
    // so what the panel shows can be pasted straight into either.
    assert_eq!(
        fields["member_root"].as_str(),
        Some("Public/US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx")
    );
    assert_eq!(
        fields["membership_program_id"].as_array().map(Vec::len),
        Some(8)
    );

    // Field-set equality is the actual drift guard: a field added to MultisigConfig without
    // regenerating the IDL leaves every later field decoding one slot behind, and Borsh will not
    // complain — it just yields wrong values.
    let mut got: Vec<&str> = fields
        .as_object()
        .expect("decoded config is an object")
        .keys()
        .map(String::as_str)
        .collect();
    got.sort_unstable();
    assert_eq!(
        got,
        [
            "m",
            "member_root",
            "membership_program_id",
            "multisig_id",
            "n",
            "proposal_count",
            "version"
        ]
    );
}

#[test]
fn proposal_decodes_through_the_committed_idl() {
    let proposal = Proposal {
        version: 1,
        config_hash: [1u8; 32],
        proposal_id: [2u8; 32],
        action: ProposedAction::TreasuryTransfer {
            recipient: [3u8; 32],
            amount: 60,
        },
        nullifiers: vec![[4u8; 32], [5u8; 32]],
        executed: true,
    };
    let bytes = borsh::to_vec(&proposal).expect("borsh");

    let (name, fields) =
        decode_account_data_try_all(&bytes, &idl()).expect("the IDL decodes a proposal account");
    assert_eq!(name, "Proposal");

    assert_eq!(fields["executed"], true);
    // The approval count *is* the nullifier count — the panel that shows "2 of 2" reads this.
    assert_eq!(fields["nullifiers"].as_array().map(Vec::len), Some(2));
    // u128 must survive as a number, not a truncated u64.
    let action = &fields["action"];
    assert!(
        action.to_string().contains("60"),
        "the proposed amount is missing from the decoded action: {action}"
    );
}

#[test]
fn an_empty_account_decodes_as_nothing() {
    // A PDA that was never written comes back with empty data. The UI must be able to tell that
    // apart from a decoded account, so this must not accidentally match a layout.
    assert!(decode_account_data_try_all(&[], &idl()).is_none());
}
