using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class MedicationRepository(DapperContext context) : IMedicationRepository
{
    public async Task<IReadOnlyList<Medication>> GetDictionaryAsync()
    {
        using var connection = context.CreateConnection();
        var entries = await connection.QueryAsync<Medication>(
            StoredProcedures.MedicationDictionaryGetAll,
            commandType: CommandType.StoredProcedure);
        return entries.ToList();
    }

    public async Task<(int PrescriptionId, string RxNumber)> CreatePrescriptionAsync(
        int caseId, int? planId, int medicationId, int? prescribedByUserId,
        string doseText, string frequency, int durationDays,
        string? instructions, string? diagnosisText,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@PlanId", planId);
        parameters.Add("@MedicationId", medicationId);
        parameters.Add("@PrescribedByUserId", prescribedByUserId);
        parameters.Add("@DoseText", doseText);
        parameters.Add("@Frequency", frequency);
        parameters.Add("@DurationDays", durationDays);
        parameters.Add("@Instructions", instructions);
        parameters.Add("@DiagnosisText", diagnosisText);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewPrescriptionId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@RxNumber", dbType: DbType.String, size: 20, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.MedicationPrescriptionCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return (
                parameters.Get<int>("@NewPrescriptionId"),
                parameters.Get<string>("@RxNumber"));
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task CancelPrescriptionAsync(
        int prescriptionId, byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@PrescriptionId", prescriptionId);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.MedicationPrescriptionCancel, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<MedicationPrescription>> GetPrescriptionsByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var prescriptions = await connection.QueryAsync<MedicationPrescription>(
            StoredProcedures.MedicationPrescriptionGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
        return prescriptions.ToList();
    }

    public async Task<int> DispenseAsync(
        int prescriptionId, DateTime dispensedDate, decimal quantity,
        int? dispensedByUserId, string? adherenceNotes,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@PrescriptionId", prescriptionId);
        parameters.Add("@DispensedDate", dispensedDate);
        parameters.Add("@Quantity", quantity);
        parameters.Add("@DispensedByUserId", dispensedByUserId);
        parameters.Add("@AdherenceNotes", adherenceNotes);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewDispenseId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.MedicationDispense, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewDispenseId");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }
}
