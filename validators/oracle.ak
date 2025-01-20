use aiken/collection/list
use cardano/assets.{flatten, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, OutputReference, Transaction, find_input,
}
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
      (ResetParameters, [_], [_]) -> {
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
