//
//  OrbVisualizerView.swift
//  OpenClaw
//
//  Animated voice visualization orb
//

import SwiftUI

struct OrbVisualizerView: View {
    let agentState: AgentMode
    let isConnected: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6
    @State private var innerRotation: Double = 0
    @State private var outerRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(gradientColor.opacity(0.3), lineWidth: 2)
                    .scaleEffect(scale + CGFloat(i) * 0.2)
                    .opacity(opacity - Double(i) * 0.15)
                    .rotationEffect(.degrees(outerRotation + Double(i) * 30))
            }
            
            // Middle animated ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [gradientColor, gradientColor.opacity(0.3), gradientColor],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .scaleEffect(scale * 0.85)
                .rotationEffect(.degrees(innerRotation))
            
            // Core orb with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: orbColors,
                        center: .center,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .scaleEffect(scale * 0.7)
                .shadow(color: gradientColor.opacity(0.6), radius: 20)
            
            // Inner highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.3), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .scaleEffect(scale * 0.5)
                .offset(x: -10, y: -10)
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: agentState) { _, newState in
            updateAnimations(for: newState)
        }
        .onChange(of: isConnected) { _, connected in
            if connected {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var gradientColor: Color {
        guard isConnected else { return .gray }
        switch agentState {
        case .speaking:
            return .orbBlue
        case .listening:
            return .orbCyan
        }
    }
    
    private var orbColors: [Color] {
        guard isConnected else {
            return [.gray, .gray.opacity(0.5), .gray.opacity(0.2)]
        }
        switch agentState {
        case .speaking:
            return [.orbBlue, .orbPurple.opacity(0.7), .orbBlue.opacity(0.3)]
        case .listening:
            return [.orbCyan, .orbBlue.opacity(0.7), .orbCyan.opacity(0.3)]
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            innerRotation = 360
        }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            outerRotation = -360
        }
        
        // Pulse based on state
        updateAnimations(for: agentState)
    }
    
    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            scale = 0.8
            opacity = 0.3
        }
    }
    
    private func updateAnimations(for state: AgentMode) {
        switch state {
        case .speaking:
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                scale = 1.15
                opacity = 0.9
            }
        case .listening:
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.0
                opacity = 0.6
            }
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundDark.ignoresSafeArea()
        
        VStack(spacing: 40) {
            OrbVisualizerView(agentState: .listening, isConnected: true)
                .frame(width: 120, height: 120)
            
            OrbVisualizerView(agentState: .speaking, isConnected: true)
                .frame(width: 120, height: 120)
            
            OrbVisualizerView(agentState: .listening, isConnected: false)
                .frame(width: 120, height: 120)
        }
    }
}
