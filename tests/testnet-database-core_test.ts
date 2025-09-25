import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Verify core functionalities of protected-testnet-database",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const admin = accounts.get('wallet_1')!;
        const user = accounts.get('wallet_2')!;

        // Test creating an access tier
        let block = chain.mineBlock([
            Tx.contractCall('testnet-database-core', 'create-access-tier', 
                [
                    types.utf8('Admin Tier'), 
                    types.bool(true), 
                    types.bool(true), 
                    types.bool(true)
                ], 
                admin.address
            )
        ]);
        
        // Assert first tier is created successfully
        assertEquals(block.receipts[0].result.expectOk(), 'u1');

        // Test adding a record with proper access tier
        block = chain.mineBlock([
            Tx.contractCall('testnet-database-core', 'add-record', 
                [
                    types.utf8('Sensitive testnet configuration data'), 
                    types.uint(1)
                ], 
                admin.address
            )
        ]);

        // Assert record is added successfully
        assertEquals(block.receipts[0].result.expectOk(), 'u1');

        // Verify record can be retrieved
        const recordCheck = chain.callReadOnlyFn('testnet-database-core', 'get-record', [types.uint(1)], user.address);
        recordCheck.result.expectSome();
    }
});

Clarinet.test({
    name: "Prevent unauthorized access and modifications",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const admin = accounts.get('wallet_1')!;
        const user = accounts.get('wallet_2')!;

        // Attempt to add record without creating an access tier should fail
        let block = chain.mineBlock([
            Tx.contractCall('testnet-database-core', 'add-record', 
                [
                    types.utf8('Unauthorized data'), 
                    types.uint(99)
                ], 
                user.address
            )
        ]);
        
        // Assert error for non-existent access tier
        block.receipts[0].result.expectErr().expectUint(106); // ERR-ACCESS-TIER-NOT-FOUND
    }
});