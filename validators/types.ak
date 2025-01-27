use cardano/address.{Address}
use cardano/assets.{PolicyId}

type Counter =
  Int

pub type OracleDatum {
  oracle_counter: Counter,
  lovelace_price: Int,
  fee_address: Address,
  script_address: Address,
  red_pocket_policy: PolicyId,
  oracle_year_zodiac: ByteArray,
}

pub type MoraBoraDeemer {
  Moracle
  Boracle
}

pub type RedPocketRedeemer {
  MintRedPocket
  ClaimRedPocket
  ResetParameters
}

pub type RedPocketDatum {
  datum_counter: Counter,
  datum_year_zodiac: ByteArray,
}
