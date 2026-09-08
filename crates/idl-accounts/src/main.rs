//! Emits the `accounts` and `types` sections of the multisig IDL.
//!
//! **Why this exists.** SPEL builds an IDL from `#[lez_program]`, but account *layouts* come from a
//! separate `#[account_type]` attribute, and its collector is a syn-level scan: it reads field
//! types as written. Our state structs write them through aliases — `Digest32`, `Threshold`,
//! `MemberCount`, `ProgramIdWords` — which that scan cannot resolve, so annotating them in place
//! would emit `Defined { "Digest32" }` references to types that do not exist and decoding would
//! still fail.
//!
//! The alternative — annotating the structs and spelling every field as `[u8; 32]` — edits crates
//! that compile *into the guest*. That changes the guest ELF, and the ELF's hash is the ProgramId
//! of the already-deployed program (docs/DEPLOYMENT.md). This tool runs on the host instead and
//! touches nothing the zkVM sees.
//!
//! It is a derivation, not a transcription: field names and types come from parsing the structs'
//! own source, and `tests/roundtrip.rs` decodes real Borsh bytes through the emitted IDL, so a
//! field added to `MultisigConfig` without regenerating fails the test rather than silently
//! producing a Basecamp panel that shows the wrong values.
//!
//! Usage: `idl-accounts <root-type>[,<root-type>…] <source.rs>…`

use std::collections::{BTreeMap, HashSet};
use std::process::ExitCode;

use spel_framework_core::account_types::{parse_enum_account_type, parse_struct_account_type};
use spel_framework_core::idl::{IdlAccountType, IdlType, IdlTypeDef};
use syn::{Item, Type};

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (roots, sources) = match args.split_first() {
        Some((roots, sources)) if !sources.is_empty() => (roots.clone(), sources.to_vec()),
        _ => {
            eprintln!("usage: idl-accounts <RootType[,RootType…]> <source.rs>…");
            return ExitCode::from(2);
        }
    };
    match run(&roots, &sources) {
        Ok(json) => {
            println!("{json}");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("FATAL: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run(roots: &str, sources: &[String]) -> Result<String, String> {
    let mut items: Vec<Item> = Vec::new();
    for path in sources {
        let text = std::fs::read_to_string(path).map_err(|e| format!("reading {path}: {e}"))?;
        let file = syn::parse_file(&text).map_err(|e| format!("parsing {path}: {e}"))?;
        items.extend(file.items);
    }

    // `type Digest32 = [u8; 32];` and friends. Aliases may name other aliases, so substitution
    // below runs to a fixed point rather than one level deep.
    let mut aliases: BTreeMap<String, Type> = BTreeMap::new();
    for item in &items {
        if let Item::Type(t) = item {
            aliases.insert(t.ident.to_string(), (*t.ty).clone());
        }
    }

    let mut accounts: Vec<IdlAccountType> = Vec::new();
    let mut types: Vec<IdlTypeDef> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    // Root types become `accounts`; everything they reference becomes `types`, transitively, so a
    // new field of a new struct type does not need this tool's arguments to change.
    let mut queue: Vec<(String, bool)> = roots
        .split(',')
        .map(|r| (r.trim().to_string(), true))
        .collect();

    while let Some((name, is_root)) = queue.pop() {
        if !seen.insert(name.clone()) {
            continue;
        }
        let parsed = parse_named(&items, &aliases, &name)?;
        for referenced in defined_refs(&parsed.type_) {
            if !seen.contains(&referenced) {
                queue.push((referenced, false));
            }
        }
        if is_root {
            accounts.push(parsed);
        } else {
            let mut def = parsed.type_;
            def.name = name;
            types.push(def);
        }
    }

    // Deterministic output: the file is committed, and a reordering diff is noise a reviewer has to
    // read to rule out.
    accounts.sort_by(|a, b| a.name.cmp(&b.name));
    types.sort_by(|a, b| a.name.cmp(&b.name));

    serde_json::to_string_pretty(&serde_json::json!({
        "accounts": accounts,
        "types": types,
    }))
    .map_err(|e| format!("serialising: {e}"))
}

/// Find `name` among the parsed items and convert it with SPEL's own parsers, after rewriting any
/// alias in its field types to the type the alias stands for.
fn parse_named(
    items: &[Item],
    aliases: &BTreeMap<String, Type>,
    name: &str,
) -> Result<IdlAccountType, String> {
    for item in items {
        match item {
            Item::Struct(s) if s.ident == name => {
                let mut s = s.clone();
                for field in s.fields.iter_mut() {
                    resolve(&mut field.ty, aliases);
                }
                return parse_struct_account_type(&s)
                    .ok_or_else(|| format!("'{name}' has no named fields"));
            }
            Item::Enum(e) if e.ident == name => {
                let mut e = e.clone();
                for variant in e.variants.iter_mut() {
                    for field in variant.fields.iter_mut() {
                        resolve(&mut field.ty, aliases);
                    }
                }
                return Ok(parse_enum_account_type(&e));
            }
            _ => {}
        }
    }
    Err(format!(
        "type '{name}' not found in the sources given — was a state struct renamed or moved?"
    ))
}

/// Replace aliases with their targets, inside generics and arrays too, to a fixed point.
fn resolve(ty: &mut Type, aliases: &BTreeMap<String, Type>) {
    for _ in 0..16 {
        let replaced = match ty {
            Type::Path(p) => match p.path.segments.last() {
                Some(seg) if seg.arguments.is_empty() => {
                    match aliases.get(&seg.ident.to_string()) {
                        Some(target) => {
                            *ty = target.clone();
                            true
                        }
                        None => false,
                    }
                }
                _ => false,
            },
            _ => false,
        };
        if !replaced {
            break;
        }
    }
    match ty {
        Type::Array(a) => resolve(&mut a.elem, aliases),
        Type::Path(p) => {
            if let Some(seg) = p.path.segments.last_mut() {
                if let syn::PathArguments::AngleBracketed(args) = &mut seg.arguments {
                    for arg in args.args.iter_mut() {
                        if let syn::GenericArgument::Type(inner) = arg {
                            resolve(inner, aliases);
                        }
                    }
                }
            }
        }
        _ => {}
    }
}

fn defined_refs(def: &IdlTypeDef) -> Vec<String> {
    let mut out = Vec::new();
    for f in &def.fields {
        walk(&f.type_, &mut out);
    }
    for v in &def.variants {
        for f in &v.fields {
            walk(&f.type_, &mut out);
        }
    }
    out
}

fn walk(ty: &IdlType, out: &mut Vec<String>) {
    match ty {
        IdlType::Defined { defined } => out.push(defined.clone()),
        IdlType::Vec { vec } => walk(vec, out),
        IdlType::Option { option } => walk(option, out),
        IdlType::Array { array: (inner, _) } => walk(inner, out),
        IdlType::Primitive(_) => {}
    }
}
