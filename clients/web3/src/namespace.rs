//! `Hmy` namespace

use crate::{Hmy, HmyFilter};

use web3::{Transport, Web3};

pub trait HmyNamespace<T: Transport>: Clone {
    fn hmy(&self) -> Hmy<T>;

    fn hmy_filter(&self) -> HmyFilter<T>;
}

impl<T: Transport> HmyNamespace<T> for Web3<T> {
    fn hmy(&self) -> Hmy<T> {
        self.api()
    }

    fn hmy_filter(&self) -> HmyFilter<T> {
        self.api()
    }
}
