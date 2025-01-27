use aiken/collection/list.{head}
use aiken/primitive/bytearray.{starts_with}
use cardano/assets.{AssetName, PolicyId, add, flatten, from_asset}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use mocktail.{
  complete, mint, mocktail_tx, ref_tx_in, ref_tx_in_inline_datum, tx_in,
  tx_in_inline_datum,
}
use mocktail/virgin_address.{mock_pub_key_address, mock_script_address}
use mocktail/virgin_key_hash.{mock_policy_id}
use mocktail/virgin_output_reference.{mock_tx_hash, mock_utxo_ref}
use types.{ClaimRedPocket, OracleDatum, RedPocketDatum, RedPocketRedeemer}
use vodka_converter.{convert_int_to_bytes}
use vodka_inputs.{inputs_at, inputs_with_policy}
use vodka_mints.{check_policy_only_burn}

validator red_pocket {
  spend(
    datum: Option<RedPocketDatum>,
    redeemer: Option<RedPocketRedeemer>,
    own_script_input: OutputReference,
    tx: Transaction,
  ) {
    when redeemer is {
      Some(ClaimRedPocket) -> {
        let Transaction { inputs, reference_inputs, mint, .. } = tx

        expect [reference_input] = reference_inputs
        expect InlineDatum(data) = reference_input.output.datum
        expect OracleDatum(
          oracle_counter,
          lovelace_price,
          fee_address,
          script_address,
          red_pocket_policy,
          oracle_year_zodiac,
        ): OracleDatum = data
        // Get input of user claiming red pocket
        expect [red_pocket_nft_input]: List<Input> =
          inputs_with_policy(inputs, red_pocket_policy)

        // Get that input's value
        let red_pocket_nft_value: List<(PolicyId, AssetName, Int)> =
          flatten(red_pocket_nft_input.output.value)
        // Get the AssetName of the user's NFT if the policyid and quantity match
        let red_pocket_value_input_values =
          red_pocket_nft_value
            |> list.filter(
                fn(asset) {
                  if asset.1st == red_pocket_policy && asset.3rd == 1 {
                    True
                  } else {
                    False
                  }
                },
              )
        expect Some(red_pocket_value) = head(red_pocket_value_input_values)
        let red_pocket_asset_name: AssetName = red_pocket_value.2nd

        // Get the datum value of that UTxO
        expect Some(RedPocketDatum(datum_counter, datum_year_zodiac)) = datum

        // We now check that the AssetName of the red pocket NFT matches
        // with the datum of the UTxO locked at script.
        // Both year of zodiac and counter need to match.
        let year_zodiac_match: Bool =
          starts_with(red_pocket_asset_name, datum_year_zodiac)

        let counter_from_asset_name: ByteArray =
          red_pocket_asset_name
            |> bytearray.drop(bytearray.length(datum_year_zodiac) + 1)

        // We convert the datum counter from throuple to int, and then to bytearray
        let datum_counter_byte: ByteArray = convert_int_to_bytes(datum_counter)
        let counter_match: Bool = counter_from_asset_name == datum_counter_byte

        // We also want to make sure that the NFT will be burned in this transaction
        let mint_value_burns_nft =
          check_policy_only_burn(mint, red_pocket_policy)

        // bundle is all up together
        if year_zodiac_match {
          if counter_match {
            if mint_value_burns_nft {
              True
            } else {
              fail @"Something wrong on the minting side"
            }
          } else {
            fail @"Counter didnt match or something else"
          }
        } else {
          fail @"Year zodiac not match"
        }
      }
      // and {
      //   year_zodiac_match,
      //   counter_match,
      //   mint_value_burns_nft,
      // }
      _ -> False
    }
  }

  else(_) {
    fail
  }
}

///
/// TESTS
///
test success_claim() {
  let redeemer = Some(ClaimRedPocket)
  let red_pocket_policy = mock_policy_id(0)
  let oracle_policy = mock_policy_id(3)
  let random_token_policy_1 = mock_policy_id(1)
  let random_token_policy_2 = mock_policy_id(2)
  let value_input_script =
    from_asset(random_token_policy_1, "", 600_000_000_000)
      |> add(random_token_policy_2, "", 5_000_000_000_000)
      |> add("", "", 30_000_000)
  let datum_input_script: RedPocketDatum =
    RedPocketDatum { datum_counter: 2, datum_year_zodiac: "Monkey" }

  let value_input_user =
    from_asset(red_pocket_policy, "Monkey 2", 1) |> add("", "", 20_000_000)

  let oracle_ref_input_value =
    from_asset(oracle_policy, "", 1) |> add("", "", 20_000_000)
  let oracle_datum: OracleDatum =
    OracleDatum {
      oracle_counter: 2,
      lovelace_price: 5_000_000,
      fee_address: mock_pub_key_address(0, None),
      script_address: mock_script_address(0, None),
      red_pocket_policy,
      oracle_year_zodiac: "Monkey",
    }

  let tx =
    mocktail_tx()
      |> ref_tx_in(
          True,
          mock_tx_hash(2),
          2,
          oracle_ref_input_value,
          mock_script_address(1, None),
        )
      |> ref_tx_in_inline_datum(True, oracle_datum)
      |> tx_in(
          True,
          mock_tx_hash(0),
          0,
          value_input_user,
          mock_pub_key_address(0, None),
        )
      |> tx_in(
          True,
          mock_tx_hash(1),
          1,
          value_input_script,
          mock_script_address(0, None),
        )
      |> tx_in_inline_datum(True, datum_input_script)
      |> mint(True, -1, red_pocket_policy, "Monkey 2")
      |> complete()

  red_pocket.spend(Some(datum_input_script), redeemer, mock_utxo_ref(0, 0), tx)
}

test counter_from_asset_name() {
  let datum_year_zodiac = "Monkey"
  let datum_counter_int = 20_000_000
  let red_pocket_asset_name = "Monkey 20000000"
  let counter_from_asset_name: ByteArray =
    red_pocket_asset_name
      |> bytearray.drop(bytearray.length(datum_year_zodiac) + 1)

  let datum_counter = convert_int_to_bytes(datum_counter_int)

  counter_from_asset_name == datum_counter
}
// Can only mint 256 Red Pockets => 1 byte = 2^8
