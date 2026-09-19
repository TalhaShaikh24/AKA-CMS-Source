using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Domain.Entities;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class UserService(
    IUserRepository userRepository,
    IAuthRepository authRepository,
    IPasswordHasher passwordHasher,
    IValidator<CreateUserRequest> createValidator,
    IValidator<UpdateUserRequest> updateValidator,
    IValidator<AssignRoleRequest> assignRoleValidator) : IUserService
{
    public async Task<IReadOnlyList<UserDto>> GetAllAsync()
    {
        var users = await userRepository.GetAllAsync();
        return users.Select(u => u.ToDto()).ToList();
    }

    public async Task<UserDto> GetByIdAsync(int userId)
    {
        var user = await userRepository.GetByIdAsync(userId)
            ?? throw new NotFoundException($"User {userId} not found.");
        return user.ToDto();
    }

    public async Task<UserDto> CreateAsync(CreateUserRequest request, int performedBy, string performedByName)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var existing = await authRepository.GetUserByUsernameAsync(request.Username);
        if (existing is not null)
            throw new ConflictException($"Username '{request.Username}' already exists.");

        var userId = await userRepository.CreateAsync(
            new User { Username = request.Username },
            passwordHasher.Hash(request.Password),
            performedBy);

        if (request.RoleIds is not null)
            foreach (var roleId in request.RoleIds.Distinct())
                await userRepository.AssignRoleAsync(userId, roleId, 0, performedByName, performedBy);

        return (await userRepository.GetByIdAsync(userId))!.ToDto();
    }

    public async Task<UserDto> UpdateAsync(int userId, UpdateUserRequest request, int performedBy)
    {
        await updateValidator.ValidateAndThrowAsync(request);

        _ = await userRepository.GetByIdAsync(userId)
            ?? throw new NotFoundException($"User {userId} not found.");

        var passwordHash = request.NewPassword is null
            ? null
            : passwordHasher.Hash(request.NewPassword);

        await userRepository.UpdateAsync(userId, request.IsActive, request.IsLocked, passwordHash, performedBy);
        return (await userRepository.GetByIdAsync(userId))!.ToDto();
    }

    public async Task AssignRoleAsync(int userId, AssignRoleRequest request, int performedBy, string performedByName)
    {
        await assignRoleValidator.ValidateAndThrowAsync(request);

        _ = await userRepository.GetByIdAsync(userId)
            ?? throw new NotFoundException($"User {userId} not found.");
        await userRepository.AssignRoleAsync(userId, request.RoleId, request.UnitCode, performedByName, performedBy);
    }

    public async Task RemoveRoleAsync(int userId, int roleId, int performedBy)
    {
        _ = await userRepository.GetByIdAsync(userId)
            ?? throw new NotFoundException($"User {userId} not found.");
        await userRepository.RemoveRoleAsync(userId, roleId, performedBy);
    }
}
