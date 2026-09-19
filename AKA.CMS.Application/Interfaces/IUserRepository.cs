using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(int userId);
    Task<IReadOnlyList<User>> GetAllAsync();
    Task<int> CreateAsync(User user, string passwordHash, int performedBy);
    Task UpdateAsync(int userId, bool? isActive, bool? isLocked, string? passwordHash, int performedBy);
    Task AssignRoleAsync(int userId, int roleId, int unitCode, string createdBy, int performedBy);
    Task RemoveRoleAsync(int userId, int roleId, int performedBy);
    Task<IReadOnlyList<string>> GetRolesAsync(int userId);
}
