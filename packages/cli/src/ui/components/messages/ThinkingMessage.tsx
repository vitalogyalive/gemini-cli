/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import type React from 'react';
import { Text, Box } from 'ink';
import type { ThoughtSummary } from '../../types.js';
import { theme } from '../../semantic-colors.js';

interface ThinkingMessageProps {
  thought: ThoughtSummary;
}

export const ThinkingMessage: React.FC<ThinkingMessageProps> = ({
  thought,
}) => {
  const prefix = '💭 ';
  const prefixWidth = 2; // Emoji width approximation

  return (
    <Box flexDirection="row">
      <Box width={prefixWidth}>
        <Text aria-label="Thinking">{prefix}</Text>
      </Box>
      <Box flexGrow={1} flexDirection="column">
        <Text color={theme.text.secondary}>
          {thought.subject && <Text bold>{thought.subject}</Text>}
          {thought.subject && thought.description && ' '}
          {thought.description}
        </Text>
      </Box>
    </Box>
  );
};
