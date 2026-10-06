using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IUserService
{
    Task<IReadOnlyList<UserDto>> GetAllAsync();
    Task<UserDto> GetByIdAsync(int userId);
    Task<UserDto> CreateAsync(CreateUserRequest request, int performedBy, string performedByName);
    Task<UserDto> UpdateAsync(int userId, UpdateUserRequest request, int performedBy);
    Task<UserDto> UpdateMyProfileAsync(int userId, UpdateMyProfileRequest request);
    Task AssignRoleAsync(int userId, AssignRoleRequest request, int performedBy, string performedByName);
    Task RemoveRoleAsync(int userId, int roleId, int performedBy);
}
