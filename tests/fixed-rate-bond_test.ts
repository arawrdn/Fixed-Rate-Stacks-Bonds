// fixed-rate-bond_test.ts

import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.148.0/testing/asserts.ts';

Clarinet.test({
    name: "Bond issuance and calculation works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        
        // 1. Issue a Bond: Principal 100 STX, Term 12 months, Rate 5% (500 BPS)
        let block = chain.mineBlock([
            Tx.contractCall(
                "fixed-rate-bond", 
                "issue-bond", 
                [
                    types.uint(100000000), // 100 STX (uSTX)
                    types.uint(12),        // 12 months
                    types.uint(500)         // 500 BPS = 5.00%
                ], 
                deployer.address
            )
        ]);
        
        // Check for successful issuance (returns bond-id u1)
        block.receipts[0].result.expectOk().expectUint(1);

        // 2. Calculate Total Return
        // Expected Return: Principal (100) + Interest (100 * 0.05 * 12/12 = 5) = 105 STX
        // In uSTX: 105,000,000
        let call = chain.callReadOnlyFn(
            "fixed-rate-bond", 
            "calculate-total-return", 
            [types.uint(1)], 
            deployer.address
        );
        
        call.result.expectOk().expectUint(105000000);
    },
});

Clarinet.test({
    name: "Bond redemption fails before maturity",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet2 = accounts.get("wallet_2")!;

        // 1. Issue Bond
        let block = chain.mineBlock([
            Tx.contractCall("fixed-rate-bond", "issue-bond", [types.uint(100000000), types.uint(1), types.uint(500)], deployer.address)
        ]);
        block.receipts[0].result.expectOk().expectUint(1);

        // 2. Attempt to Redeem Immediately (Fails with ERR-NOT-MATURED u104)
        block = chain.mineBlock([
            Tx.contractCall("fixed-rate-bond", "redeem-bond", [types.uint(1)], deployer.address)
        ]);
        
        // Error code u104 defined in contract
        block.receipts[0].result.expectErr().expectUint(104); 
    },
});

Clarinet.test({
    name: "Bond redemption works after maturity",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;

        // 1. Issue Bond (1 month term)
        let block = chain.mineBlock([
            Tx.contractCall("fixed-rate-bond", "issue-bond", [types.uint(100000000), types.uint(1), types.uint(500)], deployer.address)
        ]);
        block.receipts[0].result.expectOk().expectUint(1);
        
        // 2. Simulate time jump past maturity (1 month = 4320 blocks)
        chain.mineEmptyBlock(4320); 

        // 3. Redeem Bond (Should succeed)
        block = chain.mineBlock([
            Tx.contractCall("fixed-rate-bond", "redeem-bond", [types.uint(1)], deployer.address)
        ]);
        
        // Expects OK with the total return amount (105000000 uSTX)
        block.receipts[0].result.expectOk().expectUint(105000000); 
    },
});
