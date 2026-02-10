void main() {
  testLevel(0, 1);
  testLevel(99, 1);
  testLevel(100, 2); // Should be 2
  testLevel(101, 2);

  // Level 1->2: 100 XP. Total: 100.
  // Level 2->3: 400 XP. Total: 500.
  testLevel(499, 2);
  testLevel(500, 3); // Should be 3

  // Level 3->4: 900 XP. Total: 1400.
  testLevel(1399, 3);
  testLevel(1400, 4); // Should be 4

  // Level 4->5: 1600 XP. Total: 3000.
  testLevel(2999, 4);
  testLevel(3000, 5); // Should be 5

  // Check progress calculation for "stuck" scenario
  checkProgress(1400, 4); // Start of level 4
  checkProgress(2999, 4); // End of level 4
  checkProgress(3000, 5); // Start of level 5
}

void testLevel(int xp, int expectedLevel) {
  calculateLevel(xp);
}

void checkProgress(int xp, int currentLevel) {
  int level = calculateLevel(xp);
  int xpForCurrent = xpForLevel(level);
  int xpForNext = xpForNextLevel(level);
  int progressXp = xp - xpForCurrent;
  (progressXp / xpForNext).clamp(0.0, 1.0);
}

int calculateLevel(int xp) {
  int level = 1;
  int requiredXp = 100;
  int totalXp = 0;

  while (totalXp + requiredXp <= xp) {
    totalXp += requiredXp;
    level++;
    requiredXp = level * level * 100;
  }

  return level;
}

int xpForLevel(int level) {
  int totalXp = 0;
  for (int i = 1; i < level; i++) {
    totalXp += i * i * 100;
  }
  return totalXp;
}

int xpForNextLevel(int level) {
  return level * level * 100;
}
