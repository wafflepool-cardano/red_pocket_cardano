use aiken/primitive/bytearray.{concat}
use cardano/assets.{PolicyId}
use cardano/transaction.{InlineDatum, Transaction}
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
          oracle_year_zodiac,
        ): OracleDatum = input_datum
        // Set asset name for minted red_pocket
        let asset_name: ByteArray =
          oracle_year_zodiac // Ex. "Snake_2025"
            |> concat(" (")
            |> concat(convert_int_to_bytes(oracle_counter))
            |> concat(")")

        // Only one red pocket minted
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
