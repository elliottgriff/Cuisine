//
//  RecipeListView.swift
//  Cuisine
//
//  Created by Elliott Griffin on 3/11/25.
//

import SwiftUI

struct RecipeListView: View {
    @StateObject private var viewModel = RecipeListViewModel()
    @State private var expandedRecipeId: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Picker("Filter", selection: $viewModel.selectedFilter) {
                            ForEach(viewModel.updateAvailableFilterOptions()) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.vertical, 8)
                        
                        Spacer()
                        
                        Text("\(viewModel.filteredRecipes.count) recipes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                    .padding(.horizontal)
                    .background(
                        colorScheme == .dark ?
                            Color.black.opacity(0.8) :
                            Color.white.opacity(0.8)
                    )
                    .background(.ultraThinMaterial)
                    .zIndex(1)
                    
                    contentView
                }
            }
            .navigationTitle("Explore Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refreshRecipes()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .clipShape(Circle())
                }
            }
            .task {
                await viewModel.loadRecipes()
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .loaded:
            if viewModel.filteredRecipes.isEmpty && viewModel.selectedFilter != .all {
                emptyFilteredStateView
            } else {
                recipeListView(recipes: viewModel.filteredRecipes)
            }
        case .empty:
            emptyStateView
        case .error(let message):
            errorView(message: message)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .symbolEffect(.pulse)
            
            Text("Discovering recipes...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private func recipeListView(recipes: [Recipe]) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    Color.clear.frame(height: 1)
                        .id("top")
                    
                    ForEach(recipes) { recipe in
                        ExpandableRecipeCard(
                            recipe: recipe,
                            isExpanded: expandedRecipeId == recipe.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if expandedRecipeId == recipe.id {
                                        expandedRecipeId = nil
                                    } else {
                                        expandedRecipeId = recipe.id
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation {
                                                scrollProxy.scrollTo(recipe.id, anchor: .top)
                                            }
                                        }
                                    }
                                }
                            }
                        )
                        .id(recipe.id)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                expandedRecipeId = nil
                await viewModel.refreshRecipes()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 70))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
            
            Text("No Recipes Available")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Our chefs are busy cooking up some new recipes. Check back later!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                Task {
                    await viewModel.refreshRecipes()
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.medium)
                    .frame(height: 44)
                    .frame(maxWidth: 200)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyFilteredStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
            
            Text("No \(viewModel.selectedFilter.rawValue) Recipes")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Try selecting a different cuisine type or check back later for new recipes.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                viewModel.selectedFilter = .all
            } label: {
                Text("Show All Recipes")
                    .fontWeight(.medium)
                    .frame(height: 44)
                    .frame(maxWidth: 200)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                Task {
                    await viewModel.refreshRecipes()
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.medium)
                    .frame(height: 44)
                    .frame(maxWidth: 200)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct ExpandableRecipeCard: View {
    let recipe: Recipe
    let isExpanded: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    AsyncImageView(urlString: recipe.photoUrlLarge ?? recipe.photoUrlSmall)
                        .frame(height: isExpanded ? 250 : 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    cuisineTag
                        .padding([.top, .leading], 16)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(recipe.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    HStack {
                        if recipe.youtubeUrl != nil {
                            Label {
                                Text("Watch video")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                Capsule()
                                    .fill(colorScheme == .dark ?
                                          Color(.systemGray5) :
                                          Color(.systemGray6))
                            )
                        }
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            if isExpanded {
                VStack(spacing: 24) {
                    if let youtubeUrl = recipe.youtubeUrl {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recipe Video")
                                .font(.headline)
                                .padding(.horizontal, 16)
                            
                            YouTubePlayerView(youtubeURLString: youtubeUrl)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                        }
                    }
                    
                    if let sourceUrl = recipe.sourceUrl, let url = URL(string: sourceUrl) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Original Source")
                                .font(.headline)
                                .padding(.horizontal, 16)
                            
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18))
                                    Text("View Full Recipe")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorScheme == .dark ?
                                              Color(.systemGray5) :
                                              Color(.systemGray6))
                                )
                                .foregroundColor(.primary)
                            }
                            .padding(16)
                        }
                    }
                }
                .padding(.top, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    private var cuisineTag: some View {
        Text(recipe.cuisine)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
            )
            .foregroundColor(.white)
    }
}
struct RecipeListView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeListView()
    }
}
