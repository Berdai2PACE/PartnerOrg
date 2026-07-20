public with sharing class IncreaseOpportunityAmountController {

    private static final String INCREASE_PERCENT = 'INCREASE_PERCENT';
    private static final String DECREASE_PERCENT = 'DECREASE_PERCENT';
    private static final String INCREASE_VALUE = 'INCREASE_VALUE';
    private static final String DECREASE_VALUE = 'DECREASE_VALUE';
    private static final String REPLACE_VALUE = 'REPLACE_VALUE';

    @AuraEnabled
    public static Integer updateOpportunityAmounts(Id accountId, String changeType, Decimal value) {
        if (accountId == null || changeType == null || value == null) {
            throw new AuraHandledException('Account, change type and value are required.');
        }

        List<Opportunity> oppsToUpdate = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE AccountId = :accountId
            AND StageName != 'Closed Won'
        ];

        for (Opportunity opp : oppsToUpdate) {
            opp.Amount = applyChange(opp.Amount, changeType, value);
        }

        if (!oppsToUpdate.isEmpty()) {
            try {
                update oppsToUpdate;
            } catch (DmlException e) {
                throw new AuraHandledException('Error updating Opportunities: ' + e.getMessage());
            }
        }

        return oppsToUpdate.size();
    }

    private static Decimal applyChange(Decimal amount, String changeType, Decimal value) {
        Decimal currentAmount = amount == null ? 0 : amount;

        switch on changeType {
            when 'INCREASE_PERCENT' {
                return currentAmount + (currentAmount * value / 100);
            }
            when 'DECREASE_PERCENT' {
                return currentAmount - (currentAmount * value / 100);
            }
            when 'INCREASE_VALUE' {
                return currentAmount + value;
            }
            when 'DECREASE_VALUE' {
                return currentAmount - value;
            }
            when 'REPLACE_VALUE' {
                return value;
            }
            when else {
                throw new AuraHandledException('Unsupported change type: ' + changeType);
            }
        }
    }
}
