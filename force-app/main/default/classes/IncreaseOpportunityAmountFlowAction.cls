public with sharing class IncreaseOpportunityAmountFlowAction {

    public class FlowInput {
        @InvocableVariable(required=true label='Account Id')
        public Id accountId;

        @InvocableVariable(required=true label='Percentage')
        public Decimal percentage;
    }

    @InvocableMethod(label='Increase Opportunity Amounts')
    public static void updateOpportunityAmounts(List<FlowInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return;
        }

        FlowInput input = inputs[0];
        if (input == null || input.accountId == null || input.percentage == null) {
            return;
        }

        List<Opportunity> oppsToUpdate = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE AccountId = :input.accountId
            AND StageName != 'Closed Won'
        ];

        for (Opportunity opp : oppsToUpdate) {
            Decimal currentAmount = opp.Amount == null ? 0 : opp.Amount;
            opp.Amount = currentAmount + (currentAmount * input.percentage / 100);
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}