////////////////////// TESTS ////////////////////////
//////// TESTS

use aiken/collection/list
use cardano/assets.{PolicyId, from_lovelace}
use cardano/transaction.{Input, OutputReference, Transaction, placeholder}
use mocktail.{complete, mint, mocktail_tx, tx_in}
use mocktail/virgin_address.{mock_pub_key_address}
use mocktail/virgin_key_hash.{mock_policy_id}
use mocktail/virgin_output_reference.{mock_tx_hash, mock_utxo_ref}
use types.{Boracle, MoraBoraDeemer, Moracle}
use vodka_mints.{check_policy_only_burn}

// Only a specific UTxO can mint these Oracle NFTs
validator oracle_nft(utxo_ref: OutputReference) {
  mint(redeemer: MoraBoraDeemer, policy_id: PolicyId, tx: Transaction) {
    when redeemer is {
      Moracle -> {
        let Transaction { inputs, .. } = tx

        // We make sure that only the selected UTxO can mint the oracle nft
        let hash_equal =
          fn(input: Input) {
            let hash = input.output_reference
            utxo_ref == hash
          }
        // If the input is there, we can mint. Pretty straightforward.
        let target_input_exist: Option<Input> = list.find(inputs, hash_equal)
        when target_input_exist is {
          Some(_) -> True
          None -> False
        }
      }
      Boracle -> check_policy_only_burn(tx.mint, policy_id)
    }
  }

  else(_) {
    fail
  }
}

//
//
// Tests
test success_mint() {
  let redeemer = Moracle
  let input_utxo = mock_utxo_ref(0, 1)
  let policy_id: PolicyId = mock_policy_id(0)

  let tx =
    mocktail_tx()
      |> mint(True, 1, policy_id, "")
      |> tx_in(
          True,
          mock_tx_hash(0),
          1,
          from_lovelace(1_000_000),
          mock_pub_key_address(0, None),
        )
      |> complete()

  oracle_nft.mint(input_utxo, redeemer, policy_id, tx)
}

test fail_mint_no_utxo_ref_supply() {
  let redeemer = Moracle
  let policy_id = mock_policy_id(0)

  !oracle_nft.mint(mock_utxo_ref(0, 0), redeemer, policy_id, placeholder)
}

test success_burn() {
  let redeemer = Boracle
  let policy_id = mock_policy_id(0)

  let tx =
    mocktail_tx()
      |> mint(True, -1, policy_id, "")
      |> complete()

  oracle_nft.mint(mock_utxo_ref(0, 0), redeemer, policy_id, tx)
}

test fail_burn_with_mint() {
  let redeemer = Boracle
  let policy_id = mock_policy_id(0)

  let tx =
    mocktail_tx()
      |> mint(True, 1, policy_id, "")
      |> complete()

  !oracle_nft.mint(mock_utxo_ref(0, 0), redeemer, policy_id, tx)
}

test fail_burn_with_mix() {
  let redeemer = Boracle
  let policy_id = mock_policy_id(0)

  let tx =
    mocktail_tx()
      |> mint(True, -1, policy_id, "")
      |> mint(True, 1, policy_id, "Hinson")
      |> complete()

  !oracle_nft.mint(mock_utxo_ref(0, 0), redeemer, policy_id, tx)
}
