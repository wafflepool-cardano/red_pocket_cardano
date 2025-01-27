use aiken/primitive/bytearray.{concat}
use cardano/assets.{PolicyId, add, from_asset, from_lovelace}
use cardano/transaction.{InlineDatum, Transaction}
use mocktail.{
  complete, mint, mocktail_tx, tx_in, tx_in_inline_datum, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_address.{mock_pub_key_address, mock_script_address}
use mocktail/virgin_key_hash.{mock_policy_id}
use mocktail/virgin_output_reference.{mock_tx_hash}
use types.{
  ClaimRedPocket, MintRedPocket, OracleDatum, RedPocketDatum, RedPocketRedeemer,
}
use vodka_converter.{convert_int_to_bytes}
use vodka_inputs.{inputs_with_policy}
use vodka_mints.{check_policy_only_burn, only_minted_token}
use vodka_outputs.{outputs_at}

validator red_pocket_nft(oracle_nft: PolicyId) {
  mint(redeemer: RedPocketRedeemer, policy_id: PolicyId, tx: Transaction) {
    when redeemer is {
      MintRedPocket -> {
        let Transaction { inputs, mint, outputs, .. } = tx
        // Make sure only one RedPocket NFT is minted with the correct count.
        expect [auth_input] = inputs_with_policy(inputs, oracle_nft)
        expect InlineDatum(input_datum) = auth_input.output.datum
        expect OracleDatum(
          oracle_counter,
          lovelace_price,
          fee_address,
          script_address,
          red_pocket_policy,
          oracle_year_zodiac,
        ): OracleDatum = input_datum
        // Set asset name for minted red_pocket
        let asset_name: ByteArray =
          oracle_year_zodiac // Ex. "Snake_2025"
            |> concat(" ")
            |> concat(convert_int_to_bytes(oracle_counter))
        let only_one_red_pocket_minted: Bool =
          only_minted_token(mint, policy_id, asset_name, 1)

        // Making sure one output sends assets with RedPocketDatum to script
        // First we make sure there is an output to the script address
        expect [output_to_script] = outputs_at(outputs, script_address)
        // We also make sure that that output to script has proper datum
        expect InlineDatum(output_to_script_datum) = output_to_script.datum
        expect RedPocketDatum(datum_counter, datum_year_zodiac): RedPocketDatum =
          output_to_script_datum

        // Making sure that the counter for the datum match that of the oracle.
        let counters_match: Bool =
          oracle_counter == datum_counter && datum_year_zodiac == oracle_year_zodiac

        and {
          counters_match,
          only_one_red_pocket_minted,
        }
      }

      ClaimRedPocket -> check_policy_only_burn(tx.mint, policy_id)

      _ -> False
    }
  }

  else(_) {
    fail
  }
}

// pub fn counter_to_int(counter: (Int, Int, Int)) -> Int {
//   let int = counter.1st * 256 * 256 + counter.2nd * 256 + counter.3rd

//   int
// }

// Can play around with the test below to see
// If can mint asset with AssetName that has wrong counter name.
// Can also try messing with RedPocketDatum
///
/// TESTS
///
test success_mint() {
  let redeemer = MintRedPocket
  let oracle_policy = mock_policy_id(0)
  let red_pocket_policy = mock_policy_id(1)
  let oracle_datum: OracleDatum =
    OracleDatum {
      oracle_counter: 0,
      lovelace_price: 5_000_000,
      fee_address: mock_pub_key_address(0, None),
      script_address: mock_script_address(0, None),
      red_pocket_policy,
      oracle_year_zodiac: "Monkey",
    }

  let input_value_minter = from_lovelace(10_000_000)
  let input_value_oracle =
    from_asset(oracle_policy, "", 1) |> add("", "", 30_000_000)
  let tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          0,
          input_value_minter,
          mock_pub_key_address(0, None),
        )
      |> tx_in(
          True,
          mock_tx_hash(1),
          0,
          input_value_oracle,
          mock_script_address(0, None),
        )
      |> tx_in_inline_datum(True, oracle_datum)
      |> mint(True, 1, red_pocket_policy, "Monkey 0")
      |> tx_out(True, mock_script_address(0, None), from_lovelace(5_000_000))
      |> tx_out_inline_datum(
          True,
          RedPocketDatum { datum_counter: 0, datum_year_zodiac: "Monkey" },
        )
      |> complete()

  red_pocket_nft.mint(oracle_policy, redeemer, red_pocket_policy, tx)
}

test success_burn() {
  let redeemer = ClaimRedPocket
  let oracle_policy = mock_policy_id(0)
  let red_pocket_policy = mock_policy_id(1)

  let input_value_burner =
    from_asset(red_pocket_policy, "monkey (0)", 1) |> add("", "", 350_000_000)

  let tx =
    mocktail_tx()
      |> tx_in(
          True,
          mock_tx_hash(0),
          0,
          input_value_burner,
          mock_pub_key_address(0, None),
        )
      |> mint(True, -1, red_pocket_policy, "monkey (0)")
      |> mint(True, 1, red_pocket_policy, "monkey (0)") // this works as they cancel each other out, no nothing happens.
      |> complete()

  red_pocket_nft.mint(oracle_policy, redeemer, red_pocket_policy, tx)
}
