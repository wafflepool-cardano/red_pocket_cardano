use aiken/collection/list
use aiken/primitive/bytearray.{concat}
use cardano/assets.{add, flatten, from_asset, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, OutputReference, Transaction, find_input,
}
use mocktail.{
  complete, mint, mocktail_tx, required_signer_hash, tx_in, tx_in_inline_datum,
  tx_out, tx_out_inline_datum,
}
use mocktail/virgin_address.{mock_pub_key_address, mock_script_address}
use mocktail/virgin_key_hash.{mock_policy_id}
use mocktail/virgin_output_reference.{mock_tx_hash, mock_utxo_ref}
use types.{MintRedPocket, OracleDatum, RedPocketRedeemer, ResetParameters}
use vodka_address.{address_payment_key}
use vodka_extra_signatories.{key_signed}
use vodka_inputs.{inputs_at_with_policy}
use vodka_outputs.{outputs_at_with_policy}
use vodka_value.{get_all_value_to, value_geq}

validator oracle {
  spend(
    datum_opt: Option<OracleDatum>,
    redeemer: RedPocketRedeemer,
    input: OutputReference,
    tx: Transaction,
  ) {
    let Transaction { inputs, outputs, extra_signatories, .. } = tx

    // Oracle datum is included as a parameter?
    expect Some(OracleDatum {
      oracle_counter,
      lovelace_price,
      fee_address,
      script_address,
      red_pocket_policy,
      oracle_year_zodiac,
    }) = datum_opt

    // Selecting the oracle nft input
    expect Some(own_input) = find_input(inputs, input)
    // Isolating the oracle nft policy. Should be the first value that is not ADA
    expect [(oracle_nft_policy, _, _)] =
      list.filter(flatten(own_input.output.value), fn(x) { x.1st != "" })
    // Isolating address where oracle nft is. Should be a script address
    let own_address = own_input.output.address

    when
      (
        redeemer,
        inputs_at_with_policy(inputs, own_address, oracle_nft_policy),
        outputs_at_with_policy(outputs, own_address, oracle_nft_policy),
      )
    is {
      // If a new red pocket is minted,
      // oracle nft must be spent and
      // associated UTxO datum must be updated.
      // Therefore, script containing oracle nft must
      // spend and send to itself.
      // Note that this Tx is initiated by the user.
      (MintRedPocket, [_], [only_output]) -> {
        // We make sure there's only ADA and the oracle nft in output
        let is_output_value_clean: Bool =
          list.length(flatten(only_output.value)) == 2
        // We make sure the count is updated
        // (the currently minted red pocket will have the current 
        // oracle_count. The next minted red pocket will have the updated
        // oracle_count).
        let is_count_updated =
          only_output.datum == InlineDatum(
            OracleDatum {
              oracle_counter: oracle_counter + 1,
              lovelace_price,
              fee_address,
              script_address,
              red_pocket_policy,
              oracle_year_zodiac,
            },
          )
        // We make sure that whoever mints the red pocket
        // pays the fee to the platform. The fee address and fee
        // amount is set by the oracle.
        let is_fee_paid =
          get_all_value_to(outputs, fee_address)
            |> value_geq(from_lovelace(lovelace_price))

        and {
          is_output_value_clean,
          is_count_updated,
          is_fee_paid,
        }
      }

      // Only the admin who has the relevant keys
      // associated with fee_address can make any sort of 
      // change to the oracle.
      (ResetParameters, [_], _) -> {
        let owner_key = address_payment_key(fee_address)
        let owner_signed = key_signed(extra_signatories, owner_key)

        owner_signed
      }
      _ -> False
    }
  }

  else(_) {
    fail
  }
}

// fn update_counter(oracle_counter: (Int, Int, Int)) -> (Int, Int, Int) {
//   when oracle_counter is {
//     (255, 255, 255) -> fail @"Maximum number of Red Pockets have been minted"
//     (a, 255, 255) -> (a + 1, 0, 0)
//     (a, b, 255) -> (a, b + 1, 0)
//     (a, b, c) -> (a, b, c + 1)
//   }
// }
///
/// TESTS
///
type MintTestCase {
  is_oracle_output_clean: Bool,
  is_fee_paid: Bool,
  is_count_updated: Bool,
}

fn mock_mint_tx(test_case: MintTestCase) -> Transaction {
  let MintTestCase { is_oracle_output_clean, is_fee_paid, is_count_updated } =
    test_case
  let oracle_year_zodiac_value: ByteArray = "Monkey"
  let input_value =
    from_asset(mock_policy_id(0), "", 1) |> add("", "", 2_000_000)

  mocktail_tx()
    |> tx_in(True, mock_tx_hash(0), 0, input_value, mock_script_address(0, None))
    |> tx_in_inline_datum(
        True,
        OracleDatum {
          oracle_counter: 0,
          lovelace_price: 2_000_000,
          fee_address: mock_pub_key_address(0, None),
          script_address: mock_script_address(1, None),
          red_pocket_policy: mock_policy_id(5),
          oracle_year_zodiac: oracle_year_zodiac_value,
        },
      )
    |> tx_out(is_oracle_output_clean, mock_script_address(0, None), input_value)
    |> tx_out(
        !is_oracle_output_clean,
        mock_pub_key_address(0, None),
        input_value |> add(mock_policy_id(3), "", 1),
      )
    |> tx_out_inline_datum(
        True,
        OracleDatum {
          oracle_counter: if is_count_updated {
            1
          } else {
            0
          },
          lovelace_price: 2_000_000,
          fee_address: mock_pub_key_address(0, None),
          script_address: mock_script_address(1, None),
          red_pocket_policy: mock_policy_id(5),
          oracle_year_zodiac: oracle_year_zodiac_value,
        },
      )
    |> mint(True, 1, mock_policy_id(1), oracle_year_zodiac_value |> concat(" 0"))
    |> tx_out(is_fee_paid, mock_pub_key_address(0, None), from_lovelace(2_000_000))
    |> complete()
}

test success_mint() {
  let datum =
    OracleDatum {
      oracle_counter: 0,
      lovelace_price: 2_000_000,
      fee_address: mock_pub_key_address(0, None),
      script_address: mock_script_address(1, None),
      red_pocket_policy: mock_policy_id(5),
      oracle_year_zodiac: "Monkey",
    }

  let redeemer = MintRedPocket

  let tx =
    mock_mint_tx(
      MintTestCase {
        is_oracle_output_clean: True,
        is_fee_paid: True,
        is_count_updated: True,
      },
    )

  oracle.spend(Some(datum), redeemer, mock_utxo_ref(0, 0), tx)
}

test success_mint_fail_oracle_unclean_value() {
  let datum =
    OracleDatum {
      oracle_counter: 0,
      lovelace_price: 2_000_000,
      fee_address: mock_pub_key_address(0, None),
      script_address: mock_script_address(1, None),
      red_pocket_policy: mock_policy_id(5),
      oracle_year_zodiac: "Monkey",
    }

  let redeemer = MintRedPocket

  let tx =
    mock_mint_tx(
      MintTestCase {
        is_oracle_output_clean: False,
        is_fee_paid: True,
        is_count_updated: True,
      },
    )

  !oracle.spend(Some(datum), redeemer, mock_utxo_ref(0, 0), tx)
}

test fail_mint_without_fee_paid() {
  let datum =
    OracleDatum {
      oracle_counter: 0,
      lovelace_price: 2_000_000,
      fee_address: mock_pub_key_address(0, None),
      script_address: mock_script_address(1, None),
      red_pocket_policy: mock_policy_id(5),
      oracle_year_zodiac: "Monkey",
    }
  let redeemer = MintRedPocket

  let tx =
    mock_mint_tx(
      MintTestCase {
        is_oracle_output_clean: True,
        is_fee_paid: False,
        is_count_updated: True,
      },
    )

  !oracle.spend(Some(datum), redeemer, mock_utxo_ref(0, 0), tx)
}

test fail_mint_without_count_updated() {
  let datum =
    OracleDatum {
      oracle_counter: 0,
      lovelace_price: 2_000_000,
      fee_address: mock_pub_key_address(0, None),
      script_address: mock_script_address(1, None),
      red_pocket_policy: mock_policy_id(5),
      oracle_year_zodiac: "Monkey",
    }
  let redeemer = MintRedPocket

  let tx =
    mock_mint_tx(
      MintTestCase {
        is_oracle_output_clean: True,
        is_fee_paid: True,
        is_count_updated: False,
      },
    )

  !oracle.spend(Some(datum), redeemer, mock_utxo_ref(0, 0), tx)
}

type ResetOracleTestCase {
  is_owner_signed: Bool,
}

fn mock_reset_oracle(test_case: ResetOracleTestCase) -> Transaction {
  let ResetOracleTestCase { is_owner_signed } = test_case

  let input_value =
    from_asset(mock_policy_id(0), "", 1) |> add("", "", 5_000_000)

  let owner_sig_key_hash: ByteArray =
    address_payment_key(mock_pub_key_address(0, None))
  mocktail_tx()
    |> tx_in(True, mock_tx_hash(0), 0, input_value, mock_script_address(0, None))
    |> tx_in_inline_datum(
        True,
        OracleDatum {
          oracle_counter: 0,
          lovelace_price: 2_000_000,
          fee_address: mock_pub_key_address(0, None),
          script_address: mock_script_address(1, None),
          red_pocket_policy: mock_policy_id(5),
          oracle_year_zodiac: "Monkey",
        },
      )
    |> tx_out(
        True,
        mock_pub_key_address(0, None),
        from_asset(mock_policy_id(0), "", 1) |> add("", "", 3_000_000),
      )
    |> required_signer_hash(is_owner_signed, owner_sig_key_hash)
    |> complete()
}

test success_reset() {
  let datum =
    OracleDatum {
      oracle_counter: 0,
      lovelace_price: 2_000_000,
      fee_address: mock_pub_key_address(0, None),
      script_address: mock_script_address(1, None),
      red_pocket_policy: mock_policy_id(5),
      oracle_year_zodiac: "Monkey",
    }
  let redeemer = ResetParameters
  let tx = mock_reset_oracle(ResetOracleTestCase { is_owner_signed: True })

  oracle.spend(Some(datum), redeemer, mock_utxo_ref(0, 0), tx)
}
// test mock_tx_ok() {
//   let tx = mock_reset_oracle(ResetOracleTestCase { is_owner_signed: True })
//   let is_tx_ok: Bool =
//     if tx is Transaction {
//       trace @"It's a Transaction"
//       True
//     } else {
//       fail @"Mock Tx not ok"
//     }

//   is_tx_ok
// }
