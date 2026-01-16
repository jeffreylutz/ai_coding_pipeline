#!/usr/bin/env python3
"""
Property-based tests for documentation completeness validation.

Feature: docker-container-setup, Property 8: Documentation Completeness
Validates: Requirements 5.1, 5.2, 5.3, 5.4

This module tests that documentation exists for all major components and includes
installation verification, usage examples, and troubleshooting guidance.
"""

import pytest
import os
import re
from hypothesis import given, strategies as st, settings
from typing import List, Dict


class TestDocumentationCompleteness:
    """Test suite for documentation completeness validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        cls.pipeline_projects = [
            "kiro", "auto-claude", "continuous-claude", 
            "automaker", "infiagent", "mai-ui", "loki-mode"
        ]
        cls.additional_tools = [
            "knownote", "vibium", "opentinker", "proxypal", "claude-transcripts"
        ]
    
    def test_readme_exists_and_comprehensive(self):
        """Test that README.md exists and contains comprehensive information."""
        assert os.path.exists("README.md"), "README.md must exist"
        
        with open("README.md", "r") as f:
            content = f.read()
        
        assert len(content) > 1000, "README should be comprehensive (>1000 characters)"
        
        # Test required sections
        required_sections = [
            "Overview", "Quick Start", "Prerequisites", 
            "Build", "Run", "Pipeline Projects", "Tools",
            "Configuration", "Troubleshooting", "Usage"
        ]
        
        for section in required_sections:
            assert section in content, f"README should contain '{section}' section"
        
        # Test that it mentions Docker
        assert "docker" in content.lower(), "README should mention Docker"
        assert "container" in content.lower(), "README should mention containers"
    
    def test_dockerfile_documentation(self):
        """Test that Dockerfile contains clear build instructions."""
        assert os.path.exists("Dockerfile"), "Dockerfile must exist"
        
        with open("Dockerfile", "r") as f:
            content = f.read()
        
        # Test for comments explaining stages
        comment_lines = [line for line in content.split('\n') if line.strip().startswith('#')]
        assert len(comment_lines) >= 10, "Dockerfile should have adequate comments"
        
        # Test for stage documentation
        assert "Stage" in content, "Dockerfile should document build stages"
        
        # Test for clear instructions
        instruction_keywords = ["FROM", "RUN", "COPY", "WORKDIR", "EXPOSE", "CMD"]
        for keyword in instruction_keywords:
            assert keyword in content, f"Dockerfile should use {keyword} instruction"
    
    def test_pipeline_projects_documentation(self):
        """Test that all pipeline projects are documented."""
        with open("README.md", "r") as f:
            readme_content = f.read()
        
        for project in self.pipeline_projects:
            # Test project is mentioned in README
            project_variations = [
                project,
                project.replace('-', ' ').title(),
                project.replace('-', '').upper()
            ]
            
            found_mention = any(variation in readme_content for variation in project_variations)
            assert found_mention, f"Pipeline project {project} should be documented in README"
            
            # Test location is documented
            assert f"/opt/pipelines/{project}" in readme_content, f"Location for {project} should be documented"
            
            # Test startup script is documented
            assert f"start-{project}.sh" in readme_content, f"Startup script for {project} should be documented"
    
    def test_additional_tools_documentation(self):
        """Test that all additional tools are documented."""
        with open("README.md", "r") as f:
            readme_content = f.read()
        
        for tool in self.additional_tools:
            # Test tool is mentioned in README
            tool_variations = [
                tool,
                tool.replace('-', ' ').title(),
                tool.replace('-', '').upper()
            ]
            
            found_mention = any(variation in readme_content for variation in tool_variations)
            assert found_mention, f"Additional tool {tool} should be documented in README"
            
            # Test location is documented
            assert f"/opt/tools/{tool}" in readme_content, f"Location for {tool} should be documented"
    
    def test_usage_examples_provided(self):
        """Test that usage examples are provided for major components."""
        with open("README.md", "r") as f:
            content = f.read()
        
        # Test for code blocks (usage examples)
        code_blocks = re.findall(r'```[\s\S]*?```', content)
        assert len(code_blocks) >= 5, "README should contain multiple usage examples (code blocks)"
        
        # Test for bash examples
        bash_examples = [block for block in code_blocks if 'bash' in block or '$' in block]
        assert len(bash_examples) >= 3, "README should contain bash usage examples"
        
        # Test for Docker examples
        docker_examples = [block for block in code_blocks if 'docker' in block.lower()]
        assert len(docker_examples) >= 2, "README should contain Docker usage examples"
        
        # Test for specific usage patterns
        usage_patterns = [
            "docker run", "docker compose", "docker build",
            "start-", ".sh", "init-project"
        ]
        
        for pattern in usage_patterns:
            assert pattern in content, f"README should contain usage example with '{pattern}'"
    
    def test_troubleshooting_guidance(self):
        """Test that troubleshooting guidance is provided."""
        with open("README.md", "r") as f:
            content = f.read()
        
        # Test troubleshooting section exists
        assert "Troubleshooting" in content, "README should have troubleshooting section"
        
        # Test common issues are covered
        common_issues = [
            "permission", "memory", "port", "api key", "build"
        ]
        
        for issue in common_issues:
            assert issue.lower() in content.lower(), f"Troubleshooting should cover '{issue}' issues"
        
        # Test solutions are provided
        solution_indicators = ["fix", "solve", "check", "set", "increase", "use"]
        found_solutions = sum(1 for indicator in solution_indicators if indicator in content.lower())
        assert found_solutions >= 3, "Troubleshooting should provide multiple solutions"
    
    @settings(max_examples=5, deadline=30000)
    @given(
        project_name=st.sampled_from([
            "kiro", "auto-claude", "continuous-claude", "automaker", 
            "infiagent", "mai-ui", "loki-mode"
        ])
    )
    def test_project_documentation_completeness_property(self, project_name: str):
        """
        Property test: For any pipeline project, documentation should include
        all required information.
        
        Feature: docker-container-setup, Property 8: Documentation Completeness
        Validates: Requirements 5.2, 5.3
        """
        with open("README.md", "r") as f:
            content = f.read()
        
        # Test project has dedicated section
        project_section_patterns = [
            f"### {project_name}",
            f"## {project_name}",
            f"# {project_name}"
        ]
        
        has_section = any(pattern.lower() in content.lower() for pattern in project_section_patterns)
        assert has_section, f"Project {project_name} should have a dedicated documentation section"
        
        # Test required information is present
        required_info = [
            f"/opt/pipelines/{project_name}",  # Location
            f"start-{project_name}.sh",        # Startup script
            "Features:",                        # Features description
            "Config:"                          # Configuration info
        ]
        
        for info in required_info:
            assert info in content, f"Documentation for {project_name} should include {info}"
    
    @settings(max_examples=3, deadline=20000)
    @given(
        tool_name=st.sampled_from([
            "knownote", "vibium", "opentinker", "proxypal", "claude-transcripts"
        ])
    )
    def test_tool_documentation_completeness_property(self, tool_name: str):
        """
        Property test: For any additional tool, documentation should include
        all required information.
        
        Feature: docker-container-setup, Property 8: Documentation Completeness
        Validates: Requirements 5.2, 5.3
        """
        with open("README.md", "r") as f:
            content = f.read()
        
        # Test tool is documented
        tool_variations = [
            tool_name,
            tool_name.replace('-', ' ').title(),
            tool_name.replace('-', '').upper()
        ]
        
        found_mention = any(variation in content for variation in tool_variations)
        assert found_mention, f"Tool {tool_name} should be mentioned in documentation"
        
        # Test required information is present
        required_info = [
            f"/opt/tools/{tool_name}",         # Location
            f"start-{tool_name}.sh",           # Startup script
            "Description:",                     # Description
        ]
        
        for info in required_info:
            assert info in content, f"Documentation for {tool_name} should include {info}"
    
    def test_configuration_documentation(self):
        """Test that configuration options are well documented."""
        with open("README.md", "r") as f:
            content = f.read()
        
        # Test configuration section exists
        assert "Configuration" in content, "README should have configuration section"
        
        # Test environment variables are documented
        env_vars = ["ANTHROPIC_API_KEY", "OPENAI_API_KEY", "WORKSPACE_DIR", "LOG_LEVEL"]
        for env_var in env_vars:
            assert env_var in content, f"Environment variable {env_var} should be documented"
        
        # Test directory structure is documented
        directories = ["/workspace", "/opt/pipelines", "/opt/tools", "/opt/configs"]
        for directory in directories:
            assert directory in content, f"Directory {directory} should be documented"
        
        # Test ports are documented
        ports = ["3000", "8000", "8080", "9000"]
        for port in ports:
            assert port in content, f"Port {port} should be documented"
    
    def test_build_instructions_clarity(self):
        """Test that build instructions are clear and complete."""
        with open("README.md", "r") as f:
            content = f.read()
        
        # Test build section exists
        build_indicators = ["build", "Build", "BUILD"]
        has_build_section = any(indicator in content for indicator in build_indicators)
        assert has_build_section, "README should have build instructions"
        
        # Test specific build commands are provided
        build_commands = ["docker build", "./build.sh", "docker compose"]
        found_commands = sum(1 for cmd in build_commands if cmd in content)
        assert found_commands >= 2, "README should provide multiple build options"
        
        # Test prerequisites are mentioned
        prerequisites = ["Docker", "RAM", "disk space"]
        for prereq in prerequisites:
            assert prereq.lower() in content.lower(), f"Prerequisites should mention {prereq}"
    
    def test_docker_compose_documentation(self):
        """Test that compose.yml is properly documented."""
        assert os.path.exists("compose.yml"), "compose.yml should exist"
        
        with open("compose.yml", "r") as f:
            compose_content = f.read()
        
        # Test compose file has comments
        comment_lines = [line for line in compose_content.split('\n') if line.strip().startswith('#')]
        assert len(comment_lines) >= 3, "compose.yml should have explanatory comments"
        
        # Test README mentions docker compose
        with open("README.md", "r") as f:
            readme_content = f.read()

        assert "docker compose" in readme_content, "README should mention docker compose usage"
        assert "docker compose up" in readme_content, "README should show docker compose up command"
    
    def test_build_script_documentation(self):
        """Test that build script is documented and self-explanatory."""
        assert os.path.exists("build.sh"), "build.sh should exist"
        
        with open("build.sh", "r") as f:
            script_content = f.read()
        
        # Test script has comments
        comment_lines = [line for line in script_content.split('\n') if line.strip().startswith('#')]
        assert len(comment_lines) >= 5, "build.sh should have explanatory comments"
        
        # Test script has usage information
        usage_indicators = ["usage", "Usage", "USAGE", "help", "Help"]
        has_usage = any(indicator in script_content for indicator in usage_indicators)
        assert has_usage, "build.sh should include usage information"
        
        # Test README mentions build script
        with open("README.md", "r") as f:
            readme_content = f.read()
        
        assert "./build.sh" in readme_content, "README should mention build.sh script"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])