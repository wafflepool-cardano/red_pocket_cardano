use aiken/collection/list
use aiken/primitive/bytearray.{starts_with, to_int_big_endian}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId, flatten}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, Transaction}
use types.{ClaimRedPocket, RedPocketDatum, RedPocketRedeemer}
use vodka_inputs.{inputs_with_policy}
use vodka_mints.{check_policy_only_burn}

validator red_pocket {
  spend(
    redeemer: Option<RedPocketRedeemer>,
    policy_id: PolicyId,
    tx: Transaction,
    _datum,
  ) {
    when redeemer is {
      Some(ClaimRedPocket) -> {
        let Transaction { inputs, outputs, mint, .. } = tx

        // Get input of user claiming red pocket
        expect [red_pocket_nft_input]: List<Input> =
          inputs_with_policy(inputs, policy_id)

        // Get that input's value
        expect [red_pocket_nft_value]: List<(PolicyId, AssetName, Int)> =
          flatten(red_pocket_nft_input.output.value)
        // Get the AssetName of the user's NFT if the policyid and quantity match
        let red_pocket_asset_name: ByteArray =
          if red_pocket_nft_value.1st == policy_id && red_pocket_nft_value.3rd == 1 {
            red_pocket_nft_value.2nd
          } else {
            fail @"Input does not have valid Red Pocket NFT"
          }
        // Get the UTxO of the value that the red pocket will unlock
        expect [red_pocket_unlock_input] =
          list.filter(
            inputs,
            fn(input) {
              expect InlineDatum(data) = input.output.datum
              if data is RedPocketDatum {
                True
              } else {
                fail @"input does not have valid datum"
              }
            },
          )
        // Get the datum value of that UTxO
        expect InlineDatum(red_pocket_datum) =
          red_pocket_unlock_input.output.datum
        expect RedPocketDatum { datum_counter, datum_year_zodiac } =
          red_pocket_datum

        // We now check that the AssetName of the red pocket NFT matches
        // with the datum of the UTxO locked at script.
        // Both year of zodiac and counter need to match.
        let year_zodiac_match: Bool =
          starts_with(red_pocket_asset_name, datum_year_zodiac)

        let counter_from_asset_name: Int =
          red_pocket_asset_name
            |> bytearray.drop(bytearray.length(datum_year_zodiac))
            |> bytearray.slice(2, 2)
            |> bytearray.to_int_big_endian()

        let counter_match: Bool = counter_from_asset_name == datum_counter

        // We also want to make sure that the NFT will be burned in this transaction
        let mint_value_burns_nft = check_policy_only_burn(mint, policy_id)

        // Lastly, we want to make sure that the output goes to the owner of red pocket nft
        let nft_holder_address: Address = red_pocket_nft_input.output.address
        let value_output_to_holder: Output =
          Output(
            nft_holder_address,
            red_pocket_unlock_input.output.value,
            NoDatum,
            None,
          )
        let value_goes_to_holder: Bool =
          list.any(outputs, fn(output) { output == value_output_to_holder })
        // bundle is all up together  
        and {
          year_zodiac_match,
          counter_match,
          mint_value_burns_nft,
          value_goes_to_holder,
        }
      }
      _ -> False
    }
  }

  else(_) {
    fail
  }
}
